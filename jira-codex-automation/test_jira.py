import os
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

url = f"{BASE_URL}/search/jql"

headers = {
    "Accept": "application/json",
}

params = {
    "jql": jql,
    "fields": "summary,status,assignee,description,created,updated",
    "maxResults": 10,
}

response = requests.get(
    url,
    headers=headers,
    params=params,
    auth=(JIRA_EMAIL, JIRA_API_TOKEN),
)

print("Status:", response.status_code)

if response.status_code != 200:
    print(response.text)
    exit()

data = response.json()

issues = data.get("issues", [])

print(f"\nFound {len(issues)} assigned active Jira tasks:\n")

for issue in issues:
    key = issue["key"]
    fields = issue["fields"]
    summary = fields.get("summary")
    status = fields.get("status", {}).get("name")

    print(f"{key} | {status} | {summary}")