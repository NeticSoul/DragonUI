"""Draw the README hall of fame: one light and dark SVG per row, and the README block that links each row to its profile."""
import base64
import json
import os
import re
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
LOGIN = re.compile(r"[A-Za-z0-9-]{1,39}")
RAW = f"https://raw.githubusercontent.com/{REPO}/hall-of-fame/rows"
START, END = "<!-- hall-of-fame:start -->", "<!-- hall-of-fame:end -->"


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
            if not login or not LOGIN.fullmatch(login) or user.get("type") == "Bot" or login.lower() in EXCLUDE:
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


def title_text(x, title, theme):
    return f'<text x="{x}" y="22" font-size="15" font-weight="600" fill="{theme["text"]}">{escape(title)}</text>'


def row(x, y, login, count, best, colour, theme, avatars, clip):
    out = [f'<clipPath id="{clip}"><circle cx="{x + 12}" cy="{y + 12}" r="12"/></clipPath>']
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


def column(x, title, rows, colour, theme, avatars, prefix):
    out = [title_text(x, title, theme)]
    if not rows:
        out.append(f'<text x="{x}" y="{HEAD + 16}" font-size="13" fill="{theme["muted"]}">Nobody yet</text>')
        return out
    best = rows[0][1]
    for index, (login, count) in enumerate(rows):
        out += row(x, HEAD + index * ROW, login, count, best, colour, theme, avatars, f"{prefix}{index}")
    return out


def svg(width, height, parts):
    return "\n".join([f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" font-family="{FONT}">', *parts, "</svg>"])


def render(theme, issues, pulls, avatars):
    height = HEAD + max(len(issues), len(pulls), 1) * ROW + 8
    parts = column(0, f"Top {TOP} issuers", issues, theme["issues"], theme, avatars, "i")
    parts += column(COLUMN + GAP, f"Top {TOP} contributors", pulls, theme["pulls"], theme, avatars, "p")
    return svg(WIDTH, height, parts)


def write(path, text):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        handle.write(text)


def publish_section(out_dir, slug, x, title, rows, colour, avatars):
    best = rows[0][1] if rows else 1
    width = WIDTH // 2
    for name, theme in THEMES.items():
        write(os.path.join(out_dir, "rows", f"{slug}-head-{name}.svg"), svg(width, HEAD, [title_text(x, title, theme)]))
        for index in range(TOP):
            parts = row(x, 0, *rows[index], best, theme[colour], theme, avatars, "a") if index < len(rows) else []
            write(os.path.join(out_dir, "rows", f"{slug}-{index + 1}-{name}.svg"), svg(width, ROW, parts))


def picture(name, alt):
    return (
        f'<picture><source media="(prefers-color-scheme: dark)" srcset="{RAW}/{name}-dark.svg">'
        f'<img width="49.9%" align="top" alt="{alt}" src="{RAW}/{name}-light.svg"></picture>'
    )


def linked(slug, rows, index):
    name = f"{slug}-{index + 1}"
    if index >= len(rows):
        return picture(name, "")
    login = rows[index][0]
    return f'<a href="https://github.com/{login}">{picture(name, login)}</a>'


def readme_block(issues, pulls):
    lines = [START, "<p>", picture("issuers-head", f"Top {TOP} issuers") + picture("contributors-head", f"Top {TOP} contributors") + "<br>"]
    for index in range(TOP):
        lines.append(linked("issuers", issues, index) + linked("contributors", pulls, index) + ("<br>" if index < TOP - 1 else ""))
    return lines + ["</p>", END]


def update_readme(path, issues, pulls):
    with open(path, encoding="utf-8", newline="") as handle:
        text = handle.read()
    newline = "\r\n" if "\r\n" in text else "\n"
    start, end = text.index(START), text.index(END) + len(END)
    with open(path, "w", encoding="utf-8", newline="") as handle:
        handle.write(text[:start] + newline.join(readme_block(issues, pulls)) + text[end:])


def main():
    out_dir = sys.argv[1] if len(sys.argv) > 1 else "out"
    readme = sys.argv[2] if len(sys.argv) > 2 else "README.md"
    issues, pulls, users = collect()
    top_issues, top_pulls = ranking(issues), ranking(pulls)
    avatars = {login: avatar(users[login]) for login, _ in top_issues + top_pulls}
    for name, theme in THEMES.items():
        write(os.path.join(out_dir, f"hall-of-fame-{name}.svg"), render(theme, top_issues, top_pulls, avatars))
    publish_section(out_dir, "issuers", 0, f"Top {TOP} issuers", top_issues, "issues", avatars)
    publish_section(out_dir, "contributors", GAP // 2, f"Top {TOP} contributors", top_pulls, "pulls", avatars)
    update_readme(readme, top_issues, top_pulls)
    print("issues:", top_issues)
    print("pulls:", top_pulls)


if __name__ == "__main__":
    main()
