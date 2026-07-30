#!/usr/bin/env python3
"""Verify every Chinese source string has a complete English translation."""

from pathlib import Path
import json
import re
import sys


ROOT = Path(__file__).resolve().parents[1]
APP_NAME = ROOT.name
SOURCE_DIR = ROOT / "Sources" / APP_NAME
TABLE_PATH = SOURCE_DIR / "Resources" / "en.lproj" / "Localizable.strings"
MARKER = "L10n.tr("
PLACEHOLDER = re.compile(r"\{\{\d+\}\}")


def has_han(value: str) -> bool:
    return any("\u3400" <= character <= "\u9fff" for character in value)


def string_end(source: str, start: int) -> int:
    if source.startswith('"""', start):
        end = source.find('"""', start + 3)
        return len(source) if end < 0 else end + 3

    index = start + 1
    interpolation_depth = 0
    while index < len(source):
        if source[index] == "\\":
            if index + 1 < len(source) and source[index + 1] == "(":
                interpolation_depth += 1
                index += 2
            else:
                index += 2
            continue
        if interpolation_depth:
            if source[index] == '"':
                index = string_end(source, index)
                continue
            if source.startswith("//", index):
                newline = source.find("\n", index + 2)
                index = len(source) if newline < 0 else newline + 1
                continue
            if source.startswith("/*", index):
                end = source.find("*/", index + 2)
                index = len(source) if end < 0 else end + 2
                continue
            if source[index] == "(":
                interpolation_depth += 1
            elif source[index] == ")":
                interpolation_depth -= 1
            index += 1
            continue
        if source[index] == '"':
            return index + 1
        index += 1
    raise ValueError("unterminated Swift string literal")


def interpolation_end(source: str, open_parenthesis: int) -> int:
    index = open_parenthesis + 1
    depth = 1
    while index < len(source) and depth:
        if source[index] == '"':
            index = string_end(source, index)
            continue
        if source[index] == "(":
            depth += 1
        elif source[index] == ")":
            depth -= 1
        index += 1
    if depth:
        raise ValueError("unterminated Swift string interpolation")
    return index


def localized_template(literal: str) -> str:
    result: list[str] = []
    interpolation_count = 0
    index = 1
    while index < len(literal) - 1:
        if literal.startswith("\\(", index):
            result.append("{{" + str(interpolation_count) + "}}")
            interpolation_count += 1
            index = interpolation_end(literal, index + 1)
            continue
        if literal[index] == "\\" and index + 1 < len(literal) - 1:
            result.append(literal[index:index + 2])
            index += 2
            continue
        result.append(literal[index])
        index += 1
    return "".join(result)


def source_keys(source: str) -> set[str]:
    keys: set[str] = set()
    index = 0
    while True:
        call = source.find(MARKER, index)
        if call < 0:
            return keys
        literal_start = call + len(MARKER)
        if literal_start >= len(source) or source[literal_start] != '"':
            raise ValueError("L10n.tr must receive a direct string literal")
        end = string_end(source, literal_start)
        keys.add(localized_template(source[literal_start:end]))
        index = literal_start + 1


def unwrapped_chinese_lines(source: str) -> list[int]:
    lines: list[int] = []
    index = 0
    while index < len(source):
        if source.startswith("//", index):
            newline = source.find("\n", index + 2)
            index = len(source) if newline < 0 else newline + 1
            continue
        if source.startswith("/*", index):
            end = source.find("*/", index + 2)
            index = len(source) if end < 0 else end + 2
            continue
        if source[index] == '"':
            end = string_end(source, index)
            literal = source[index:end]
            prefix = source[max(0, index - len(MARKER)):index]
            if not literal.startswith('"""') and has_han(literal) and prefix != MARKER:
                lines.append(source.count("\n", 0, index) + 1)
            index = end
            continue
        index += 1
    return lines


def read_table() -> dict[str, str]:
    table: dict[str, str] = {}
    entry_pattern = re.compile(r'^((?:"|[^"\\])*)" = "((?:\\.|[^"\\])*)";$')
    for line_number, raw_line in enumerate(TABLE_PATH.read_text().splitlines(), 1):
        line = raw_line.strip()
        if not line or line.startswith("/*") or line.startswith("//"):
            continue
        if not line.startswith('"'):
            raise ValueError(f"{TABLE_PATH}:{line_number}: invalid strings entry")
        match = entry_pattern.fullmatch(line[1:])
        if not match:
            raise ValueError(f"{TABLE_PATH}:{line_number}: invalid strings entry")
        key = json.loads('"' + match.group(1) + '"')
        value = json.loads('"' + match.group(2) + '"')
        if key in table:
            raise ValueError(f"{TABLE_PATH}:{line_number}: duplicate key: {key}")
        table[key] = value
    return table


def main() -> int:
    keys: set[str] = set()
    errors: list[str] = []
    for path in sorted(SOURCE_DIR.glob("*.swift")):
        source = path.read_text()
        keys.update(source_keys(source))
        for line in unwrapped_chinese_lines(source):
            errors.append(f"unwrapped Chinese source string: {path}:{line}")

    table = read_table()
    for key in sorted(keys - table.keys()):
        errors.append(f"missing English translation: {key}")
    for key in sorted(keys & table.keys()):
        value = table[key]
        if has_han(value):
            errors.append(f"English translation contains Chinese: {key}")
        if sorted(PLACEHOLDER.findall(key)) != sorted(PLACEHOLDER.findall(value)):
            errors.append(f"placeholder mismatch: {key}")

    if errors:
        print("\n".join(errors), file=sys.stderr)
        return 1
    print(f"localization verification passed: {len(keys)} source keys")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
