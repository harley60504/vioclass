from __future__ import annotations

import re
from pathlib import Path


def matching_brace(text: str, open_index: int) -> int:
    depth = 0
    in_string = None
    escaped = False
    i = open_index
    while i < len(text):
        c = text[i]
        if in_string is not None:
            if escaped:
                escaped = False
            elif c == '\\':
                escaped = True
            elif c == in_string:
                in_string = None
            i += 1
            continue
        if c in "'\"":
            in_string = c
        elif c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i
        i += 1
    raise RuntimeError('unmatched class brace')


def add_change_notifier_bridges(class_file: Path, class_name: str, need_notify: bool, need_has: bool) -> None:
    if not need_notify and not need_has:
        return
    text = class_file.read_text(encoding='utf-8')
    m = re.search(r'\bclass\s+' + re.escape(class_name) + r'\b', text)
    if not m:
        raise RuntimeError(f'class {class_name} not found in {class_file}')
    open_index = text.find('{', m.end())
    close_index = matching_brace(text, open_index)
    additions = []
    if need_notify and '_notifyPartListeners' not in text:
        additions.append('  void _notifyPartListeners() => notifyListeners();')
    if need_has and '_partHasListeners' not in text:
        additions.append('  bool get _partHasListeners => hasListeners;')
    if additions:
        insertion = '\n\n' + '\n'.join(additions) + '\n'
        text = text[:close_index] + insertion + text[close_index:]
        class_file.write_text(text, encoding='utf-8')


def qualify_static_refs(text: str, class_name: str, names: list[str]) -> str:
    for name in sorted(names, key=len, reverse=True):
        text = re.sub(
            r'(?<![A-Za-z0-9_.])' + re.escape(name) + r'\b',
            class_name + '.' + name,
            text,
        )
    return text


def fix_extensions(
    part_dir: Path,
    class_file_name: str,
    class_name: str,
    static_names: list[str],
) -> None:
    extension_files = []
    need_notify = False
    need_has = False
    for path in sorted(part_dir.glob('*.dart')):
        text = path.read_text(encoding='utf-8')
        if f'on {class_name}' not in text or 'extension ' not in text:
            continue
        extension_files.append(path)
        if 'notifyListeners()' in text:
            need_notify = True
            text = text.replace('notifyListeners()', '_notifyPartListeners()')
        if re.search(r'(?<![A-Za-z0-9_.])hasListeners\b', text):
            need_has = True
            text = re.sub(r'(?<![A-Za-z0-9_.])hasListeners\b', '_partHasListeners', text)
        text = qualify_static_refs(text, class_name, static_names)
        path.write_text(text, encoding='utf-8')

    class_file = next((p for p in part_dir.glob('*.dart') if f'class {class_name}' in p.read_text(encoding='utf-8')), None)
    if class_file is None:
        raise RuntimeError(f'class part for {class_name} not found in {part_dir}')
    add_change_notifier_bridges(class_file, class_name, need_notify, need_has)
    print(f'fixed {class_name}: extensions={len(extension_files)}, notify_bridge={need_notify}, has_bridge={need_has}')


def main() -> None:
    fix_extensions(
        Path('lib/features/twitch/services/playback/twitch_playlist_player_runtime_parts'),
        'twitch_playlist_player_runtime.dart',
        'TwitchPlaylistPlayerRuntime',
        [
            '_qualityKey',
            '_qualityChannelPrefix',
            '_legacyQualityKey',
            '_legacyQualityChannelPrefix',
            '_firstRunMobileFallbackHeight',
            '_firstRunMobileFallbackMaxFps',
            '_dvrHealthyCheckInterval',
            '_dvrUnavailableRetryInterval',
            '_dvrFailuresBeforeRecovery',
            '_sharedProxy',
            '_sharedBridgeProxy',
            '_sharedBridgeSeekRequestId',
        ],
    )
    fix_extensions(
        Path('lib/features/twitch/services/chat/twitch_chat_runtime_parts'),
        'twitch_chat_runtime.dart',
        'TwitchChatRuntime',
        [
            'initialUserStateWait',
            'sendUserStateWait',
            'pendingOutgoingTtl',
        ],
    )


if __name__ == '__main__':
    main()
