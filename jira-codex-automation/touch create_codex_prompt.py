import os
import re
import requests
from dotenv import load_dotenv

load_dotenv()

JIRA_EMAIL = os.getenv("JIRA_EMAIL")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")
JIRA_CLOUD_ID = os.getenv("JIRA_CLOUD_ID")
JIRA_PROJECT_KEY = os.getenv("JIRA_PROJECT_KEY")
JIRA_ASSIGNEE_ACCOUNT_ID = os.getenv("JIRA_ASSIGNEE_ACCOUNT_ID")

BASE_URL = f"https://api.atlassian.com/ex/jira/{JIRA_CLOUD_ID}/rest/api/3"

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

print("Status:", response.status_code)

if response.status_code != 200:
    print(response.text)
    exit(1)

issues = response.json().get("issues", [])

if not issues:
    print("No active Jira task assigned.")
    exit(0)

issue = issues[0]
key = issue["key"]
fields = issue["fields"]
summary = fields.get("summary", "")
status = fields.get("status", {}).get("name", "")

safe_title = re.sub(r"[^a-zA-Z0-9]+", "-", summary.lower()).strip("-")
branch_name = f"{key.lower()}-{safe_title[:50]}"

prompt = f"""
You are working on the Glowante Flutter app.

Jira Issue:
{key}

Status:
{status}

Title:
{summary}

Task:
Implement the Jira issue in the Flutter app.

Rules:
- Create or use branch: {branch_name}
- Implement only this Jira task.
- Do not change unrelated UI or logic.
- Follow existing project structure.
- Check login phone input flow.
- Fix copy-paste functionality for phone number login field.
- Preserve existing validation and country code behavior.
- After implementation, run flutter analyze.
- Mention changed files and testing notes.

Expected final response:
1. Summary of changes
2. Files changed
3. How tested
4. Any pending backend/API dependency
"""

file_name = f"codex_prompt_{key}.txt"

with open(file_name, "w", encoding="utf-8") as file:
    file.write(prompt.strip())

print(f"Created Codex prompt: {file_name}")
print(f"Suggested branch: {branch_name}")