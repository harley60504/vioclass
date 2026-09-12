from __future__ import annotations

import re
from pathlib import Path
from typing import Callable

TARGETS = [
    Path('lib/features/twitch/services/playback/twitch_hls_low_latency_proxy.dart'),
    Path('lib/features/twitch/presentation/pages/twitch_drops_connection_page.dart'),
    Path('lib/features/twitch/presentation/pages/twitch_channel_page.dart'),
    Path('lib/features/twitch/services/playback/twitch_playlist_player_runtime.dart'),
    Path('lib/features/twitch/presentation/pages/twitch_stream_page.dart'),
    Path('lib/features/twitch/services/chat/twitch_chat_runtime.dart'),
]

MAX_PART_BYTES = 18_000


def mask_code(text: str) -> str:
    out = list(text)
    i = 0
    n = len(text)
    state = 'code'
    quote = ''
    triple = False
    raw = False
    block_depth = 0
    while i < n:
        c = text[i]
        nxt = text[i + 1] if i + 1 < n else ''
        if state == 'code':
            if c == '/' and nxt == '/':
                out[i] = out[i + 1] = ' '
                i += 2
                state = 'line_comment'
                continue
            if c == '/' and nxt == '*':
                out[i] = out[i + 1] = ' '
                i += 2
                state = 'block_comment'
                block_depth = 1
                continue
            is_raw = c in 'rR' and nxt in "'\"" and (i == 0 or not (text[i - 1].isalnum() or text[i - 1] == '_'))
            if is_raw:
                raw = True
                out[i] = ' '
                i += 1
                c = text[i]
                nxt = text[i + 1] if i + 1 < n else ''
            if c in "'\"":
                quote = c
                triple = text[i:i + 3] == c * 3
                span = 3 if triple else 1
                for j in range(span):
                    if i + j < n:
                        out[i + j] = ' '
                i += span
                state = 'string'
                continue
            i += 1
            continue
        if state == 'line_comment':
            if c == '\n':
                state = 'code'
            else:
                out[i] = ' '
            i += 1
            continue
        if state == 'block_comment':
            out[i] = ' '
            if c == '/' and nxt == '*':
                out[i + 1] = ' '
                block_depth += 1
                i += 2
                continue
            if c == '*' and nxt == '/':
                out[i + 1] = ' '
                block_depth -= 1
                i += 2
                if block_depth == 0:
                    state = 'code'
                continue
            i += 1
            continue
        if state == 'string':
            out[i] = ' '
            if not raw and c == '\\':
                if i + 1 < n:
                    out[i + 1] = ' '
                i += 2
                continue
            if triple:
                if text[i:i + 3] == quote * 3:
                    for j in range(3):
                        if i + j < n:
                            out[i + j] = ' '
                    i += 3
                    state = 'code'
                    raw = False
                    triple = False
                    continue
            elif c == quote:
                i += 1
                state = 'code'
                raw = False
                continue
            i += 1
            continue
    return ''.join(out)


def matching_brace(masked: str, open_index: int) -> int:
    depth = 0
    for i in range(open_index, len(masked)):
        c = masked[i]
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
    raise ValueError('unmatched brace')


def directive_prefix_end(text: str) -> int:
    matches = list(re.finditer(r'(?m)^(?:library|import|export)\b[^;\n]*;[ \t]*(?:\n|$)', text))
    if not matches:
        return 0
    return matches[-1].end()


def split_declarations(body: str) -> list[str]:
    masked = mask_code(body)
    blocks: list[str] = []
    start = 0
    curly = paren = bracket = 0
    first_brace = None
    block_like = False
    i = 0
    while i < len(masked):
        c = masked[i]
        if c == '(':
            paren += 1
        elif c == ')':
            paren = max(0, paren - 1)
        elif c == '[':
            bracket += 1
        elif c == ']':
            bracket = max(0, bracket - 1)
        elif c == '{' and paren == 0 and bracket == 0:
            if curly == 0:
                first_brace = i
                header = masked[start:i]
                header_clean = re.sub(r'\s+', ' ', header).strip()
                has_assignment = '=' in header_clean and '=>' not in header_clean
                block_like = (
                    not has_assignment
                    and (
                        re.search(r'\b(class|enum|mixin|extension)\b', header_clean) is not None
                        or ')' in header_clean
                        or re.search(r'\bget\s+[A-Za-z_]\w*$', header_clean) is not None
                        or re.search(r'\bset\s+[A-Za-z_]\w*\s*\(', header_clean) is not None
                    )
                )
            curly += 1
        elif c == '}' and paren == 0 and bracket == 0:
            curly = max(0, curly - 1)
            if curly == 0 and block_like:
                end = i + 1
                blocks.append(body[start:end])
                start = end
                first_brace = None
                block_like = False
        elif c == ';' and curly == 0 and paren == 0 and bracket == 0:
            end = i + 1
            blocks.append(body[start:end])
            start = end
            first_brace = None
            block_like = False
        i += 1
    if body[start:].strip():
        blocks.append(body[start:])
    return [b for b in blocks if b.strip()]


def declaration_name(block: str) -> str:
    clean = mask_code(block)
    m = re.search(r'\b(?:class|enum|mixin)\s+([A-Za-z_]\w*)', clean)
    if m:
        return m.group(1)
    m = re.search(r'\bextension(?:\s+type)?(?:\s+([A-Za-z_]\w*))?\s+on\b', clean)
    if m and m.group(1):
        return m.group(1)
    header = clean[: clean.find('{') if '{' in clean else len(clean)]
    calls = list(re.finditer(r'([A-Za-z_]\w*)\s*\(', header))
    if calls:
        return calls[0].group(1)
    m = re.search(r'\b(?:const|final|var|late)\s+(?:[A-Za-z0-9_<>,?. ]+\s+)?([A-Za-z_]\w*)\s*(?:=|;)', header)
    if m:
        return m.group(1)
    return 'part'


def slugify(name: str) -> str:
    name = name.lstrip('_') or 'part'
    name = re.sub(r'([a-z0-9])([A-Z])', r'\1_\2', name)
    name = re.sub(r'[^A-Za-z0-9_]+', '_', name).strip('_').lower()
    return name or 'part'


def class_member_spans(class_block: str, class_name: str) -> tuple[int, int, list[tuple[int, int]]]:
    masked = mask_code(class_block)
    cm = re.search(r'\bclass\s+' + re.escape(class_name) + r'\b', masked)
    if not cm:
        return -1, -1, []
    open_index = masked.find('{', cm.end())
    if open_index < 0:
        return -1, -1, []
    close_index = matching_brace(masked, open_index)
    body_start = open_index + 1
    body_end = close_index
    body_mask = masked[body_start:body_end]
    spans: list[tuple[int, int]] = []
    start = 0
    curly = paren = bracket = 0
    block_like = False
    i = 0
    while i < len(body_mask):
        c = body_mask[i]
        if c == '(':
            paren += 1
        elif c == ')':
            paren = max(0, paren - 1)
        elif c == '[':
            bracket += 1
        elif c == ']':
            bracket = max(0, bracket - 1)
        elif c == '{' and paren == 0 and bracket == 0:
            if curly == 0:
                header = body_mask[start:i]
                h = re.sub(r'\s+', ' ', header).strip()
                has_assignment = '=' in h and '=>' not in h
                block_like = not has_assignment and (')' in h or re.search(r'\bget\s+\w+$', h) is not None)
            curly += 1
        elif c == '}' and paren == 0 and bracket == 0:
            curly = max(0, curly - 1)
            if curly == 0 and block_like:
                end = i + 1
                spans.append((body_start + start, body_start + end))
                start = end
                block_like = False
        elif c == ';' and curly == 0 and paren == 0 and bracket == 0:
            end = i + 1
            spans.append((body_start + start, body_start + end))
            start = end
            block_like = False
        i += 1
    if class_block[body_start + start:body_end].strip():
        spans.append((body_start + start, body_end))
    return open_index, close_index, spans


def private_method_name(member: str, class_name: str) -> str | None:
    masked = mask_code(member)
    if '@override' in member or re.search(r'\bstatic\b', masked):
        return None
    first_brace = masked.find('{')
    if first_brace < 0:
        return None
    header = masked[:first_brace]
    if '=' in header and '=>' not in header:
        return None
    calls = list(re.finditer(r'([A-Za-z_]\w*)\s*\(', header))
    if not calls:
        return None
    name = calls[0].group(1)
    if name == class_name or not name.startswith('_'):
        return None
    if 'super.' in member:
        return None
    return name


def replace_bare_method_refs(code: str, names: set[str]) -> str:
    if not names:
        return code
    masked = mask_code(code)
    matches: list[tuple[int, int, str]] = []
    for name in sorted(names, key=len, reverse=True):
        for m in re.finditer(r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\b', masked):
            matches.append((m.start(), m.end(), 'this.' + name))
    for start, end, replacement in sorted(matches, reverse=True):
        code = code[:start] + replacement + code[end:]
    return code


def rewrite_moved_method(member: str, moved_names: set[str]) -> str:
    masked = mask_code(member)
    open_index = masked.find('{')
    if open_index < 0:
        return member
    return member[:open_index + 1] + replace_bare_method_refs(member[open_index + 1:], moved_names)


def extract_private_methods(
    class_block: str,
    class_name: str,
    classifier: Callable[[str], str],
    skip_if_contains: tuple[str, ...] = (),
) -> tuple[str, list[str]]:
    _, _, spans = class_member_spans(class_block, class_name)
    if not spans:
        return class_block, []
    selected: list[tuple[int, int, str, str]] = []
    for start, end in spans:
        member = class_block[start:end]
        name = private_method_name(member, class_name)
        if name is None:
            continue
        if any(token in member for token in skip_if_contains):
            continue
        selected.append((start, end, name, member))
    if not selected:
        return class_block, []

    moved_names = {item[2] for item in selected}
    groups: dict[str, list[str]] = {}
    for _, _, name, member in selected:
        groups.setdefault(classifier(name), []).append(rewrite_moved_method(member, moved_names))

    rebuilt = class_block
    for start, end, _, _ in sorted(selected, reverse=True):
        rebuilt = rebuilt[:start] + rebuilt[end:]
    rebuilt = replace_bare_method_refs(rebuilt, moved_names)

    extensions: list[str] = []
    for category, members in groups.items():
        ext_name = '_' + class_name.lstrip('_') + ''.join(p.title() for p in category.split('_')) + 'Ops'
        joined = '\n'.join(m.strip('\n') for m in members)
        extensions.append(f"\nextension {ext_name} on {class_name} {{\n{joined}\n}}\n")
    return rebuilt, extensions


def playlist_classifier(name: str) -> str:
    n = name.lower()
    if 'dvr' in n:
        return 'dvr'
    if any(k in n for k in ('quality', 'variant', 'preferred')):
        return 'quality'
    if any(k in n for k in ('canonical', 'timeline', 'timing')):
        return 'timeline'
    if any(k in n for k in ('proxy', 'router', 'upstream', 'replay', 'buffer')):
        return 'proxy'
    return 'core'


def chat_classifier(name: str) -> str:
    n = name.lower()
    if any(k in n for k in ('send', 'outgoing', 'pending', 'reject')):
        return 'outgoing'
    if any(k in n for k in ('recent', 'initial', 'history')):
        return 'history'
    if any(k in n for k in ('message', 'handle', 'append', 'fingerprint', 'delete', 'dedup')):
        return 'messages'
    if any(k in n for k in ('state', 'room', 'user', 'badge')):
        return 'state'
    return 'connection'


def stream_classifier(name: str) -> str:
    n = name.lower()
    if any(k in n for k in ('pip', 'playback', 'mini')):
        return 'playback'
    if any(k in n for k in ('update', 'login', 'auth')):
        return 'session'
    if 'search' in n:
        return 'search'
    return 'core'


def transform_large_classes(path: Path, body: str) -> str:
    configs: list[tuple[str, Callable[[str], str], tuple[str, ...]]] = []
    if path.name == 'twitch_playlist_player_runtime.dart':
        configs.append(('TwitchPlaylistPlayerRuntime', playlist_classifier, ()))
    elif path.name == 'twitch_chat_runtime.dart':
        configs.append(('TwitchChatRuntime', chat_classifier, ()))
    elif path.name == 'twitch_stream_page.dart':
        configs.append(('_TwitchStreamPageState', stream_classifier, ('setState(',)))

    for class_name, classifier, skip_tokens in configs:
        decls = split_declarations(body)
        new_decls: list[str] = []
        found = False
        for decl in decls:
            if re.search(r'\bclass\s+' + re.escape(class_name) + r'\b', mask_code(decl)):
                rewritten, extensions = extract_private_methods(decl, class_name, classifier, skip_tokens)
                new_decls.append(rewritten)
                new_decls.extend(extensions)
                found = True
            else:
                new_decls.append(decl)
        if found:
            body = '\n'.join(d.rstrip() for d in new_decls if d.strip()) + '\n'
    return body


def split_target(path: Path) -> tuple[str, dict[Path, str]]:
    text = path.read_text(encoding='utf-8')
    prefix_end = directive_prefix_end(text)
    prefix = text[:prefix_end].rstrip()
    body = text[prefix_end:]
    body = transform_large_classes(path, body)
    declarations = split_declarations(body)
    if not declarations:
        raise RuntimeError(f'No declarations found in {path}')

    groups: list[list[str]] = []
    current: list[str] = []
    current_size = 0
    for decl in declarations:
        size = len(decl.encode('utf-8'))
        if current and current_size + size > MAX_PART_BYTES:
            groups.append(current)
            current = []
            current_size = 0
        current.append(decl)
        current_size += size
    if current:
        groups.append(current)

    part_dir = path.parent / (path.stem + '_parts')
    generated: dict[Path, str] = {}
    used: dict[str, int] = {}
    part_directives: list[str] = []
    sizes: list[int] = []
    for index, group in enumerate(groups, 1):
        base = slugify(declaration_name(group[0]))
        used[base] = used.get(base, 0) + 1
        suffix = '' if used[base] == 1 else f'_{used[base]}'
        filename = f'{index:02d}_{base}{suffix}.dart'
        part_path = part_dir / filename
        part_rel = f'{part_dir.name}/{filename}'
        part_directives.append(f"part '{part_rel}';")
        content = f"part of '../{path.name}';\n\n" + '\n'.join(d.strip('\n') for d in group).rstrip() + '\n'
        generated[part_path] = content
        sizes.append(len(content.encode('utf-8')))

    main_content = prefix + '\n\n' + '\n'.join(part_directives) + '\n'
    print(f'{path}: {len(text.encode("utf-8"))} bytes -> shell {len(main_content.encode("utf-8"))} bytes, {len(groups)} parts, max={max(sizes)}')
    return main_content, generated


def main() -> None:
    all_generated: dict[Path, str] = {}
    for target in TARGETS:
        if not target.exists():
            raise SystemExit(f'Missing target: {target}')
        main_content, generated = split_target(target)
        target.write_text(main_content, encoding='utf-8')
        all_generated.update(generated)
    for path, content in all_generated.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding='utf-8')


if __name__ == '__main__':
    main()
