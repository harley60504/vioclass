from __future__ import annotations

import re
from pathlib import Path

from refactor_large_dart import class_member_spans, mask_code, matching_brace


def add_change_notifier_bridges(class_file: Path, class_name: str, need_notify: bool, need_has: bool) -> None:
    if not need_notify and not need_has:
        return
    text = class_file.read_text(encoding='utf-8')
    masked = mask_code(text)
    m = re.search(r'\bclass\s+' + re.escape(class_name) + r'\b', masked)
    if not m:
        raise RuntimeError(f'class {class_name} not found in {class_file}')
    open_index = masked.find('{', m.end())
    close_index = matching_brace(masked, open_index)
    additions = []
    if need_notify and '_notifyPartListeners' not in text:
        additions.append('  void _notifyPartListeners() => notifyListeners();')
    if need_has and '_partHasListeners' not in text:
        additions.append('  bool get _partHasListeners => hasListeners;')
    if additions:
        insertion = '\n\n' + '\n'.join(additions) + '\n'
        text = text[:close_index] + insertion + text[close_index:]
        class_file.write_text(text, encoding='utf-8')


def discover_static_names(class_text: str, class_name: str) -> set[str]:
    _, _, spans = class_member_spans(class_text, class_name)
    names: set[str] = set()
    for start, end in spans:
        member = mask_code(class_text[start:end]).strip()
        if not member.startswith('static '):
            continue
        header = member
        marker_positions = [
            pos
            for marker in ('=>', '=', ';', '{')
            if (pos := header.find(marker)) >= 0
        ]
        if marker_positions:
            header = header[: min(marker_positions)]
        method_match = re.search(r'([A-Za-z_]\w*)\s*\(', header)
        if method_match:
            names.add(method_match.group(1))
            continue
        identifiers = re.findall(r'[A-Za-z_]\w*', header)
        if identifiers:
            names.add(identifiers[-1])
    return names


def qualify_static_refs(text: str, class_name: str, names: set[str]) -> str:
    # Extensions cannot access a static member through `this`. The splitter may
    # have inserted `this.` while making cross-extension private calls explicit,
    # so normalize both instance-looking and bare static references here.
    for name in sorted(names, key=len, reverse=True):
        text = text.replace(f'this.{name}', f'{class_name}.{name}')

    masked = mask_code(text)
    replacements: list[tuple[int, int, str]] = []
    for name in sorted(names, key=len, reverse=True):
        pattern = r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\b'
        for match in re.finditer(pattern, masked):
            replacements.append((match.start(), match.end(), class_name + '.' + name))
    for start, end, replacement in sorted(replacements, reverse=True):
        text = text[:start] + replacement + text[end:]
    return text


def fix_extensions(part_dir: Path, class_name: str) -> None:
    class_file = next(
        (
            p
            for p in part_dir.glob('*.dart')
            if re.search(r'\bclass\s+' + re.escape(class_name) + r'\b', mask_code(p.read_text(encoding='utf-8')))
        ),
        None,
    )
    if class_file is None:
        raise RuntimeError(f'class part for {class_name} not found in {part_dir}')
    class_text = class_file.read_text(encoding='utf-8')
    static_names = discover_static_names(class_text, class_name)

    extension_files = []
    need_notify = False
    need_has = False
    for path in sorted(part_dir.glob('*.dart')):
        text = path.read_text(encoding='utf-8')
        if f'on {class_name}' not in text or 'extension ' not in text:
            continue
        extension_files.append(path)
        masked = mask_code(text)
        if re.search(r'(?<![A-Za-z0-9_.])notifyListeners\s*\(\s*\)', masked) or 'this.notifyListeners()' in masked:
            need_notify = True
            text = text.replace('this.notifyListeners()', 'this._notifyPartListeners()')
            text = text.replace('notifyListeners()', '_notifyPartListeners()')
        masked = mask_code(text)
        if re.search(r'(?<![A-Za-z0-9_.])hasListeners\b', masked) or 'this.hasListeners' in masked:
            need_has = True
            text = text.replace('this.hasListeners', 'this._partHasListeners')
            text = re.sub(r'(?<![A-Za-z0-9_.])hasListeners\b', '_partHasListeners', text)
        text = qualify_static_refs(text, class_name, static_names)
        path.write_text(text, encoding='utf-8')

    add_change_notifier_bridges(class_file, class_name, need_notify, need_has)
    print(
        f'fixed {class_name}: extensions={len(extension_files)}, '
        f'statics={sorted(static_names)}, notify_bridge={need_notify}, has_bridge={need_has}'
    )


def main() -> None:
    fix_extensions(
        Path('lib/features/twitch/services/playback/twitch_playlist_player_runtime_parts'),
        'TwitchPlaylistPlayerRuntime',
    )
    fix_extensions(
        Path('lib/features/twitch/services/chat/twitch_chat_runtime_parts'),
        'TwitchChatRuntime',
    )


if __name__ == '__main__':
    main()
