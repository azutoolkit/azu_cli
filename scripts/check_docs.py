#!/usr/bin/env python3
"""Checks that docs/ will build as a GitBook space and follow design/writing-docs.md.

Usage: scripts/check_docs.py [files...]   (no files: every page in docs/)
Exit code 1 when a check fails.
"""
import glob, os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")

SECTIONS = ["Overview", "Quickstart", "Realistic output", "Do's and don'ts"]
HINT_STYLES = {"info", "warning", "success", "danger"}
MERMAID = ("flowchart", "graph", "sequenceDiagram", "classDiagram", "stateDiagram", "erDiagram", "gantt", "journey", "pie")
# Pages that are not documentation of a feature and so do not need the four sections.
LAYOUT_EXEMPT = {"SUMMARY.md"}


def registered_commands():
    names = set()
    with open(os.path.join(ROOT, "src/azu_cli/cli.cr")) as f:
        for m in re.finditer(r'register_command\("([^"]+)"', f.read()):
            names.add(m.group(1))
    return names


# YAML reads an unquoted value with ": " or " #" in it, or one starting with an indicator, as something other
# than a string, and GitBook then refuses the whole import ("Error while updating content").
YAML_INDICATORS = tuple("[]{}&*!|>'\"%@`#,?:-")


def front_matter_errors(text):
    if not text.startswith("---\n") or "\n---" not in text[3:]:
        return []
    errs = []
    for line in text[4:text.index("\n---", 3)].splitlines():
        m = re.match(r"^(\w[\w-]*):\s*(.*)$", line)
        if not m:
            errs.append(f"front matter line is not 'key: value': {line!r}")
            continue
        value = m.group(2)
        if value[:1] in ("'", '"') and value.endswith(value[0]) and len(value) > 1:
            continue
        if ": " in value or value.endswith(":") or " #" in value or value.startswith(YAML_INDICATORS):
            errs.append(f"front matter {m.group(1)} is not plain YAML (': ', ' #' or a leading indicator): quote it or reword it")
    return errs


def strip_fences(text):
    return re.sub(r"^```.*?^```", "", text, flags=re.S | re.M)


def check(path, commands, summary_pages):
    rel = os.path.relpath(path, DOCS)
    text = open(path).read()
    errs = []
    body = strip_fences(text)

    # --- GitBook syntax -------------------------------------------------
    errs += front_matter_errors(text)
    for opener, closer in [("tabs", "endtabs"), ("tab", "endtab"), ("hint", "endhint"), ("code", "endcode")]:
        o = len(re.findall(r"\{%\s*" + opener + r"(?:\s|%\})", text))
        c = len(re.findall(r"\{%\s*" + closer + r"\s*%\}", text))
        if o != c:
            errs.append(f"unbalanced {{% {opener} %}} ({o}) and {{% {closer} %}} ({c})")
    for m in re.finditer(r'{%\s*hint\s+style="([^"]*)"', text):
        if m.group(1) not in HINT_STYLES:
            errs.append(f"unknown hint style {m.group(1)!r}")
    prose = re.sub(r"`[^`\n]*`", "", body)
    if re.search(r"{%\s*(details|enddetails)", prose):
        errs.append("{% details %} does not exist in GitBook: use <details><summary>")
    if len(re.findall(r"<details>", prose)) != len(re.findall(r"</details>", prose)):
        errs.append("unbalanced <details>")
    if len(re.findall(r"<figure>", text)) != len(re.findall(r"</figure>", text)):
        errs.append("unbalanced <figure>")
    if re.search(r"^```\w*\s+title=", text, flags=re.M):
        errs.append('code fence with title="": wrap it in {% code title="..." %} ... {% endcode %}')
    if "#gh-dark-mode-only" in text or "#gh-light-mode-only" in text:
        errs.append("GitHub-only image suffix; use one image")
    if len(re.findall(r"^```", text, flags=re.M)) % 2:
        errs.append("unbalanced ``` fence")
    for m in re.finditer(r"^```mermaid\n(.*?)^```", text, flags=re.S | re.M):
        if not m.group(1).strip().startswith(MERMAID):
            errs.append("mermaid block does not start with a diagram type")

    # --- layout ---------------------------------------------------------
    if rel not in LAYOUT_EXEMPT:
        if not text.startswith("---\ndescription:"):
            errs.append("missing front matter description")
        headings = re.findall(r"^##\s+(.*)$", body, flags=re.M)
        for s in SECTIONS:
            if not any(h.lower().startswith(s.lower()) for h in headings):
                errs.append(f"missing section '## {s}'")
        if "```mermaid" not in text:
            errs.append("no mermaid diagram")
        if "<img" not in text:
            errs.append("no screenshot")
        if len(re.findall(r"\{%\s*hint\s", text)) < 2:
            errs.append("fewer than two hint blocks")
    if not re.search(r"^# \S", text, flags=re.M | re.S):
        errs.append("no H1")

    # --- links and images -----------------------------------------------
    for m in re.finditer(r"\]\(([^)\s]+?)(#[^)]*)?\)|src=\"([^\"]+)\"|url=\"([^\"]+)\"", body + "\n" + "\n".join(re.findall(r"<figure>.*?</figure>", text, flags=re.S)) + "\n" + "\n".join(re.findall(r"{%\s*content-ref[^%]*%}", text))):
        u = m.group(1) or m.group(3) or m.group(4)
        if u.startswith(("http", "mailto", "#", "data:")):
            continue
        target = os.path.normpath(os.path.join(os.path.dirname(path), u))
        if not os.path.exists(target):
            errs.append(f"broken link {u}")
    if rel not in summary_pages and rel != "SUMMARY.md" and rel != "README.md":
        errs.append("page is not in SUMMARY.md")

    # --- documented commands exist --------------------------------------
    for block in re.findall(r"^```(?:bash|sh|shell|text)?\n(.*?)^```", text, flags=re.S | re.M):
        for line in block.splitlines():
            m = re.match(r"^\s*\$?\s*azu\s+([a-z][a-z0-9:_-]*)", line)
            if m and m.group(1) not in commands:
                errs.append(f"documents unregistered command 'azu {m.group(1)}'")
    return errs


def main():
    commands = registered_commands()
    summary = open(os.path.join(DOCS, "SUMMARY.md")).read()
    summary_pages = {os.path.normpath(p) for p in re.findall(r"\]\(([^)#]+\.md)", summary)}
    files = sys.argv[1:] or sorted(glob.glob(os.path.join(DOCS, "**/*.md"), recursive=True))
    failed = 0
    for f in files:
        f = os.path.abspath(f)
        errs = sorted(set(check(f, commands, summary_pages)))
        if errs:
            failed += 1
            print(os.path.relpath(f, ROOT))
            for e in errs:
                print("   -", e)
    for p in summary_pages:
        if not os.path.exists(os.path.join(DOCS, p)):
            print(f"SUMMARY.md links to missing {p}")
            failed += 1
    print(f"{len(files)} pages checked, {failed} with problems")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
