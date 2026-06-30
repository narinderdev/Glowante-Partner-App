import os
import subprocess
import requests
from datetime import datetime
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
    print(f"\n$ {command}", flush=True)

    process = subprocess.Popen(
        command,
        cwd=cwd,
        shell=True,
        text=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        bufsize=1,
    )

    output_lines = []

    if process.stdout:
        for line in process.stdout:
            print(line, end="", flush=True)
            output_lines.append(line)

    process.wait()

    class Result:
        def __init__(self, returncode, stdout):
            self.returncode = returncode
            self.stdout = stdout
            self.stderr = ""

    result = Result(process.returncode, "".join(output_lines))

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


def print_current_app_changes():
    print("\nCurrent app changes:", flush=True)

    run(
        "git status --short -- ':!jira-codex-automation'",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    print("\nChanged files summary:", flush=True)

    run(
        "git diff --stat -- ':!jira-codex-automation'",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )


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
        "git status --short -- ':!jira-codex-automation'",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    if git_status.stdout.strip():
        print("\nYour working tree already has app changes.")
        print("Please review/commit/stash existing app changes before running automation.")
        print_current_app_changes()
        return

    transition_jira_issue(
        key,
        ["In Progress", "Start Progress", "Selected for Development"]
    )

    prompt = f"""
You are working on the Glowante Flutter app.

Jira Issue: {key}
Current Jira Status: {status}
Jira Title: {summary}

Task:
Implement this Jira task directly on the current bloc branch.

Specific issue:
Copy-paste is not working in the login phone number field.

Implementation instructions:
- Search the Flutter project for login screen files.
- Search for TextFormField/TextField used for phone number input.
- Check files under lib/screens, lib/features, lib/bloc/auth, lib/bloc/otp.
- Find where phone number validation and controller logic is implemented.
- Enable normal paste behavior in the phone input field.
- If inputFormatters block paste, update them safely.
- If pasted value contains country code like +91, remove only the selected country code part and keep the local phone number.
- If pasted value contains spaces, dashes, brackets, or invisible characters, normalize it safely.
- Example pasted values should work:
  - +91 98765 43210
  - 98765 43210
  - 9876543210
  - +91-98765-43210
- Do not break manual typing.
- Do not break country code dropdown/selection.
- Do not change unrelated login/OTP logic.
- Make actual code changes. Do not only explain.

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
- Do not touch .env, venv, secrets, build files, generated files, or automation files.
- Do not modify anything inside jira-codex-automation.
- After implementation, run flutter analyze.
- Fix analyzer issues only if caused by your changes.
- Existing analyzer warnings/info should not be fixed unless directly related to this issue.

Required output:
1. Summary of changes
2. Files changed
3. Testing done
4. Any pending dependency
"""

    prompt_file = os.path.join(FLUTTER_REPO_PATH, "codex_jira_task_prompt.txt")

    with open(prompt_file, "w", encoding="utf-8") as file:
        file.write(prompt.strip())

    print("\nStarting Codex implementation. You will now see live Codex output below...\n", flush=True)

    codex_result = run(
        'codex exec --full-auto "$(cat codex_jira_task_prompt.txt)"',
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    logs_dir = os.path.join(FLUTTER_REPO_PATH, "jira-codex-automation", "logs")
    os.makedirs(logs_dir, exist_ok=True)

    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(logs_dir, f"{key}_{timestamp}_codex_output.txt")

    with open(log_file, "w", encoding="utf-8") as file:
        file.write(codex_result.stdout)

    print(f"\nCodex output saved to: {log_file}")

    run(
        "rm -f codex_jira_task_prompt.txt",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    if codex_result.returncode != 0:
        add_jira_comment(
            key,
            "Codex automation attempted implementation but Codex command failed. Please check local terminal output/logs."
        )
        print("Codex command failed.")
        return

    print("\nRunning flutter analyze...", flush=True)

    run(
        "flutter analyze",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    diff = run(
        "git status --short -- ':!jira-codex-automation'",
        cwd=FLUTTER_REPO_PATH,
        check=False,
    )

    if not diff.stdout.strip():
        print("No code changes created by Codex.")

        add_jira_comment(
            key,
            "Automation checked this task, but Codex did not create any code changes."
        )
        return

    print_current_app_changes()

    add_jira_comment(
        key,
        "Codex automation implemented changes locally on bloc branch. Please review, test, commit, and push manually."
    )

    print("\nAutomation completed.")
    print("Changes are local only.")
    print("\nReview using:")
    print("cd /Users/apnitormacmini3/Desktop/Glowante_onboarding_latest")
    print("git status --short -- ':!jira-codex-automation'")
    print("git diff --stat -- ':!jira-codex-automation'")
    print("git diff -- ':!jira-codex-automation'")
    print("\nAfter review, manually run:")
    print("git add .")
    print(f'git commit -m "{key}: {summary}"')
    print("git push")


if __name__ == "__main__":
    main()