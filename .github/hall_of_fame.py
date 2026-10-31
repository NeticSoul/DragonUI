"""Draw the README hall of fame: who opened the most issues and pull requests, closed ones included, light and dark SVGs."""
import base64
import json
import os
import sys
import urllib.request
from collections import Counter
from xml.sax.saxutils import escape

REPO = os.environ.get("GITHUB_REPOSITORY", "NeticSoul/DragonUI")
TOKEN = os.environ.get("GITHUB_TOKEN", "")
EXCLUDE = {name.strip().lower() for name in os.environ.get("HOF_EXCLUDE", REPO.split("/")[0]).split(",") if name.strip()}
TOP = int(os.environ.get("HOF_TOP", "10"))

THEMES = {
    "dark": {"text": "#e6edf3", "muted": "#8b949e", "track": "#21262d", "issues": "#d29922", "pulls": "#2f9be0"},
    "light": {"text": "#1f2328", "muted": "#59636e", "track": "#eaeef2", "issues": "#bf8700", "pulls": "#1784d1"},
}
FONT = "-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif"
WIDTH, COLUMN, GAP, ROW, HEAD = 840, 400, 40, 32, 40


def fetch(url, accept="application/vnd.github+json"):
    request = urllib.request.Request(url, headers={"Accept": accept, "User-Agent": "dragonui-hall-of-fame"})
    if TOKEN and "api.github.com" in url:
        request.add_header("Authorization", "Bearer " + TOKEN)
    with urllib.request.urlopen(request, timeout=30) as response:
        return response.read(), response.headers.get("Content-Type", "")


def collect():
    issues, pulls, users = Counter(), Counter(), {}
    page = 1
    while True:
        body, _ = fetch(f"https://api.github.com/repos/{REPO}/issues?state=all&per_page=100&page={page}")
        items = json.loads(body)
        if not items:
            break
        for item in items:
            user = item.get("user") or {}
            login = user.get("login")
            if not login or user.get("type") == "Bot" or login.lower() in EXCLUDE:
                continue
            users[login] = user.get("avatar_url", "")
            (pulls if "pull_request" in item else issues)[login] += 1
        page += 1
    return issues, pulls, users


def avatar(url):
    if not url:
        return ""
    try:
        data, kind = fetch(url + ("&" if "?" in url else "?") + "s=48", accept="image/*")
    except OSError:
        return ""
    return "data:%s;base64,%s" % (kind.split(";")[0] or "image/png", base64.b64encode(data).decode("ascii"))


def ranking(counter):
    return sorted(counter.items(), key=lambda pair: (-pair[1], pair[0].lower()))[:TOP]


def column(x, title, rows, colour, theme, avatars, prefix):
    out = [f'<text x="{x}" y="22" font-size="15" font-weight="600" fill="{theme["text"]}">{escape(title)}</text>']
    if not rows:
        out.append(f'<text x="{x}" y="{HEAD + 16}" font-size="13" fill="{theme["muted"]}">Nobody yet</text>')
        return out
    best = rows[0][1]
    for index, (login, count) in enumerate(rows):
        y = HEAD + index * ROW
        clip = f"{prefix}{index}"
        out.append(f'<clipPath id="{clip}"><circle cx="{x + 12}" cy="{y + 12}" r="12"/></clipPath>')
        out.append(f'<circle cx="{x + 12}" cy="{y + 12}" r="12" fill="{theme["track"]}"/>')
        if avatars.get(login):
            out.append(f'<image href="{avatars[login]}" x="{x}" y="{y}" width="24" height="24" clip-path="url(#{clip})"/>')
        out.append(f'<text x="{x + 34}" y="{y + 16}" font-size="13" fill="{theme["text"]}">{escape(login)}</text>')
        bar_x, bar_w = x + 190, COLUMN - 190 - 34
        fill = max(4, round(bar_w * count / best))
        out.append(f'<rect x="{bar_x}" y="{y + 6}" width="{bar_w}" height="12" rx="6" fill="{theme["track"]}"/>')
        out.append(f'<rect x="{bar_x}" y="{y + 6}" width="{fill}" height="12" rx="6" fill="{colour}"/>')
        out.append(f'<text x="{x + COLUMN}" y="{y + 16}" font-size="13" font-weight="600" text-anchor="end" fill="{theme["text"]}">{count}</text>')
    return out


def render(theme, issues, pulls, avatars):
    height = HEAD + max(len(issues), len(pulls), 1) * ROW + 8
    parts = [f'<svg xmlns="http://www.w3.org/2000/svg" width="{WIDTH}" height="{height}" viewBox="0 0 {WIDTH} {height}" font-family="{FONT}">']
    parts += column(0, f"Top {TOP} issuers", issues, theme["issues"], theme, avatars, "i")
    parts += column(COLUMN + GAP, f"Top {TOP} contributors", pulls, theme["pulls"], theme, avatars, "p")
    parts.append("</svg>")
    return "\n".join(parts)


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "out"
    os.makedirs(out_dir, exist_ok=True)
    issues, pulls, users = collect()
    top_issues, top_pulls = ranking(issues), ranking(pulls)
    avatars = {login: avatar(users[login]) for login, _ in top_issues + top_pulls}
    for name, theme in THEMES.items():
        with open(os.path.join(out_dir, f"hall-of-fame-{name}.svg"), "w", encoding="utf-8") as handle:
            handle.write(render(theme, top_issues, top_pulls, avatars))
    print("issues:", top_issues)
    print("pulls:", top_pulls)


if __name__ == "__main__":
    main()
