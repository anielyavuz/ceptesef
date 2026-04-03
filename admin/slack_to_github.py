"""
Slack → GitHub Issue Köprüsü

Belirli bir Slack kanalını dinler.
🐛 emoji reaction eklenen mesajları GitHub Issue olarak açar
ve 'claude-fix' label'ı ekler.

Kurulum:
  1. Slack App oluştur (api.slack.com) → Bot Token Scopes:
     - channels:history, channels:read, reactions:read
  2. GitHub Personal Access Token oluştur (repo scope)
  3. Environment variable'ları ayarla:
     export SLACK_BOT_TOKEN="xoxb-..."
     export GITHUB_TOKEN="ghp_..."
     export SLACK_CHANNEL_ID="C07XXXXXX"
  4. python3 slack_to_github.py

Gereksinimler:
  pip install slack-sdk requests
"""

import os
import time
import requests
from slack_sdk import WebClient
from slack_sdk.errors import SlackApiError

# ─── Config ────────────────────────────────────────────
SLACK_BOT_TOKEN = os.environ["SLACK_BOT_TOKEN"]
GITHUB_TOKEN = os.environ["GITHUB_TOKEN"]
SLACK_CHANNEL_ID = os.environ.get("SLACK_CHANNEL_ID", "")
GITHUB_REPO = "anielyavuz/ceptesef"
TRIGGER_EMOJI = "bug"  # 🐛 emoji
POLL_INTERVAL = 30  # saniye

# ─── Clients ───────────────────────────────────────────
slack = WebClient(token=SLACK_BOT_TOKEN)
GITHUB_API = f"https://api.github.com/repos/{GITHUB_REPO}"
GITHUB_HEADERS = {
    "Authorization": f"Bearer {GITHUB_TOKEN}",
    "Accept": "application/vnd.github+json",
}

# Daha önce işlenen mesajları takip et
processed_messages = set()


def create_github_issue(title: str, body: str) -> dict:
    """GitHub'da claude-fix label'lı issue oluşturur."""
    resp = requests.post(
        f"{GITHUB_API}/issues",
        headers=GITHUB_HEADERS,
        json={
            "title": f"🐛 {title}",
            "body": body,
            "labels": ["claude-fix"],
        },
    )
    resp.raise_for_status()
    return resp.json()


def get_reactions(channel: str, timestamp: str) -> list[str]:
    """Mesajdaki reaction emoji'lerini döndürür."""
    try:
        result = slack.reactions_get(channel=channel, timestamp=timestamp)
        message = result.get("message", {})
        reactions = message.get("reactions", [])
        return [r["name"] for r in reactions]
    except SlackApiError:
        return []


def poll_channel():
    """Kanalı poll eder, 🐛 reaction'lı mesajları issue'ya çevirir."""
    try:
        result = slack.conversations_history(
            channel=SLACK_CHANNEL_ID, limit=20
        )
        messages = result.get("messages", [])

        for msg in messages:
            ts = msg.get("ts", "")
            if ts in processed_messages:
                continue

            reactions = [r["name"] for r in msg.get("reactions", [])]
            if TRIGGER_EMOJI not in reactions:
                continue

            text = msg.get("text", "").strip()
            if not text:
                continue

            # İlk satır başlık, geri kalan body
            lines = text.split("\n", 1)
            title = lines[0][:100]
            body = (
                f"**Slack'ten gelen bug raporu:**\n\n"
                f"{text}\n\n"
                f"---\n"
                f"_Slack mesaj ID: {ts}_"
            )

            issue = create_github_issue(title, body)
            print(f"✅ Issue #{issue['number']} oluşturuldu: {issue['html_url']}")

            # İşlendiğini işaretle
            processed_messages.add(ts)

            # Slack'e onay mesajı gönder
            try:
                slack.chat_postMessage(
                    channel=SLACK_CHANNEL_ID,
                    thread_ts=ts,
                    text=f"🤖 GitHub Issue oluşturuldu: {issue['html_url']}\nClaude şimdi fix üzerinde çalışacak...",
                )
            except SlackApiError:
                pass

    except SlackApiError as e:
        print(f"❌ Slack API hatası: {e}")


def ensure_label_exists():
    """claude-fix label'ının var olduğundan emin ol."""
    resp = requests.get(
        f"{GITHUB_API}/labels/claude-fix", headers=GITHUB_HEADERS
    )
    if resp.status_code == 404:
        requests.post(
            f"{GITHUB_API}/labels",
            headers=GITHUB_HEADERS,
            json={
                "name": "claude-fix",
                "color": "d73a4a",
                "description": "Claude Code ile otomatik fix",
            },
        )
        print("✅ 'claude-fix' label oluşturuldu")
    else:
        print("✅ 'claude-fix' label mevcut")


if __name__ == "__main__":
    print("🚀 Slack → GitHub köprüsü başlatılıyor...")
    print(f"   Kanal: {SLACK_CHANNEL_ID}")
    print(f"   Repo: {GITHUB_REPO}")
    print(f"   Tetikleyici: :{TRIGGER_EMOJI}: emoji")
    print(f"   Poll aralığı: {POLL_INTERVAL}sn")
    print()

    ensure_label_exists()

    while True:
        poll_channel()
        time.sleep(POLL_INTERVAL)
