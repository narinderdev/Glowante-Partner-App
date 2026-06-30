import os
import re
import subprocess
import requests
from dotenv import load_dotenv

load_dotenv()

JIRA_EMAIL = os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")
JIRA_CLOUD_ID = os.getenv("JIRA_CLOUD_ID")
JIRA_PROJECT_KEY = os.getenv("JIRA_PROJECT_KEY")
JIRA_ASSIGNEE_ACCOUNT_ID = os.getenv("JIRA_ASSIGNEE_ACCOUNT_ID")
FLUTTER_REPO_PATH = os.getenv("FLUTTER_REPO_PATH")

BASE_URL = f"https://api.atlassian.com/ex/jira/{JIRA_CLOUD_ID}/rest/api/3"


def run(command, cwd=None, check=True):
    print(f"\n$ {command}")

    result = subprocess.run(
        command,
        cwd=cwd,
        shell=True,
        text=True,
        capture_output=True,
    )

    if result.stdout:
        print(result.stdout)

    if result.stderr:
        print(result.stderr)

    if check and result.returncode != 0:
        raise Exception(f"Command failed: {command}")

    return result


def get_latest_assigned_issue():
    jql = (
        f'project = "{JIRA_PROJECT_KEY}" '
        f'AND assignee = "{JIRA_ASSIGNEE_ACCOUNT_ID}" '
        f'AND statusCategory != Done '
        f'ORDER BY updated DESC'
    )

    response = requests.get(
        f"{BASE_URL}/search/jql",
        headers={"Accept": "application/json"},
        params={
            "jql": jql,
            "fields": "summary,status,description,created,updated",
            "maxResults": 1,
        },
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
    )

    print("Jira search status:", response.status_code)

    if response.status_code != 200:
        print(response.text)
        return None

    issues = response.json().get("issues", [])
    return issues[0] if issues else None


def add_jira_comment(issue_key, comment_text):
    payload = {
        "body": {
            "type": "doc",
            "version": 1,
            "content": [
                {
                    "type": "paragraph",
                    "content": [
                        {
                            "type": "text",
                            "text": comment_text,
                        }
                    ],
                }
            ],
        }
    }

    response = requests.post(
        f"{BASE_URL}/issue/{issue_key}/comment",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
        json=payload,
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
    )

    print("Jira comment status:", response.status_code)

    if response.status_code not in [200, 201]:
        print(response.text)


def get_jira_transitions(issue_key):
    response = requests.get(
        f"{BASE_URL}/issue/{issue_key}/transitions",
        headers={"Accept": "application/json"},
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
    )

    print("Get transitions status:", response.status_code)

    if response.status_code != 200:
        print(response.text)
        return []

    return response.json().get("transitions", [])


def transition_jira_issue(issue_key, target_status_names):
    transitions = get_jira_transitions(issue_key)

    if not transitions:
        print("No transitions found.")
        return False

    print("Available transitions:")
    for transition in transitions:
        transition_name = transition.get("name", "")
        to_status = transition.get("to", {}).get("name", "")
        print(f'- {transition.get("id")} | {transition_name} -> {to_status}')

    target_status_names = [name.lower() for name in target_status_names]

    selected_transition = None

    for transition in transitions:
        transition_name = transition.get("name", "").lower()
        to_status = transition.get("to", {}).get("name", "").lower()

        if transition_name in target_status_names or to_status in target_status_names:
            selected_transition = transition
            break

    if not selected_transition:
        print(f"No matching transition found for: {target_status_names}")
        return False

    response = requests.post(
        f"{BASE_URL}/issue/{issue_key}/transitions",
        headers={
            "Accept": "application/json",
            "Content-Type": "application/json",
        },
        json={
            "transition": {
                "id": selected_transition["id"]
            }
        },
        auth=(JIRA_EMAIL, JIRA_API_TOKEN),
    )

    print("Transition Jira status:", response.status_code)

    if response.status_code not in [200, 204]:
        print(response.text)
        return False

    print(f"Moved {issue_key} using transition: {selected_transition.get('name')}")
    return True


def main():
    if not FLUTTER_REPO_PATH:
        raise Exception("FLUTTER_REPO_PATH missing in .env")

    issue = get_latest_assigned_issue()

    if not issue:
        print("No active Jira task assigned.")
        return

    key = issue["key"]
    fields = issue["fields"]
    summary = fields.get("summary", "")
    status = fields.get("status", {}).get("name", "")

    print(f"\nWorking on: {key} - {summary}")
    print(f"Current Jira status: {status}")

    current_branch = run(
        "git branch --show-current",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    ).stdout.strip()

    if current_branch != "bloc":
        print(f"Current branch is {current_branch}, not bloc.")
        print("Please checkout bloc branch first.")
        return

    git_status = run(
        "git status --short",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    if git_status.stdout.strip():
        print("Your working tree already has changes.")
        print("Please commit/stash/review existing changes before running automation.")
        return

    transition_jira_issue(
        key,
        ["In Progress", "Start Progress", "Selected for Development"]
    )

    prompt = f"""
You are working on the Glowante Flutter app.

Jira Issue: {key}
Current Status: {status}
Title: {summary}

Task:
Implement this Jira task directly on the current bloc branch.

Specific issue:
{summary}

Important rules:
- Work only on this issue.
- Do not create a new branch.
- Do not commit.
- Do not push.
- Do not create a PR.
- Modify code only in the existing working tree.
- Do not modify unrelated files.
- Do not do large refactoring.
- Preserve existing app design.
- Preserve existing validation.
- Preserve existing country code behavior.
- Fix login phone input copy-paste behavior.
- If pasted value contains country code like +91 or spaces, clean it safely according to existing app logic.
- Do not touch .env, venv, secrets, or generated files.
- After implementation, run flutter analyze.
- Fix analyzer issues only if caused by your changes.

Final answer should include:
1. Summary of changes
2. Files changed
3. Testing done
4. Any pending dependency
"""

    run(f'codex exec --full-auto "{prompt}"', cwd=FLUTTER_REPO_PATH, check=False)

    analyze_result = run("flutter analyze", cwd=FLUTTER_REPO_PATH, check=False)

    diff = run("git status --short", cwd=FLUTTER_REPO_PATH, check=False)

    if not diff.stdout.strip():
        print("No code changes created by Codex.")
        add_jira_comment(
            key,
            "Automation checked this task, but Codex did not create any code changes."
        )
        return

    add_jira_comment(
        key,
        "Codex automation implemented changes locally on bloc branch. Please review, test, commit, and push manually."
    )

    print("\nAutomation completed.")
    print("Changes are local only.")
    print("Review using:")
    print("git diff")
    print("git status")
    print("\nAfter review, you can manually run:")
    print("git add .")
    print(f'git commit -m "{key}: {summary}"')
    print("git push")


if __name__ == "__main__":
    main()