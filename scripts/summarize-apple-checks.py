#!/usr/bin/env python3
"""Expose actionable Apple CI errors in the run summary and annotations.

No API access or credentials are required. Full logs/xcresult remain artifacts.
"""
import json
import os
from pathlib import Path
import re
import subprocess


def log_failures(text):
    text = re.sub(r'\x1b\[[0-9;]*m', '', text)
    pattern = re.compile(r'error:|XCTAssert|failed|failure|Testing failed|Unable to|Could not|timed out|crash|Error Domain', re.I)
    return [line.strip() for line in text.splitlines() if pattern.search(line)][-60:]


def result_failures(data):
    issues = data.get('issues', {})
    messages = []
    for category in ('testFailureSummaries', 'errorSummaries'):
        for issue in issues.get(category, {}).get('_values', []):
            name = issue.get('testCaseName', {}).get('_value', '')
            message = issue.get('message', {}).get('_value', '')
            if message:
                messages.append(f'{name}: {message}' if name else message)
    return messages


def annotation(message):
    return message.replace('%', '%25').replace('\r', '%0D').replace('\n', '%0A')


def main():
    directory = Path('.build/apple-verification')
    sections = []
    errors = []
    result = directory / 'native-tests.xcresult'
    if result.exists():
        command = ['xcrun', 'xcresulttool', 'get', 'object', '--legacy', '--path', str(result), '--format', 'json']
        response = subprocess.run(command, capture_output=True, text=True)
        if response.returncode == 0:
            try:
                errors.extend(result_failures(json.loads(response.stdout)))
            except (ValueError, TypeError) as error:
                sections.append(f'Could not read xcresult failure summaries: {error}')
        else:
            sections.append('xcresult extraction unavailable; filtered text logs follow.')
    for log in sorted(directory.glob('*.log')):
        lines = log_failures(log.read_text(errors='replace'))
        if lines:
            sections.append(f'### {log.name}\n\n````text\n' + '\n'.join(lines) + '\n````')
            errors.extend(line for line in lines if re.search(r'error:|XCTAssert|Test Case .*failed|Testing failed|Failed to', line, re.I))
    unique = list(dict.fromkeys(errors))
    report = '# Apple build and test diagnostics\n\n'
    if unique:
        report += '## Reported failures\n\n````text\n' + '\n'.join(unique[:30]) + '\n````\n\n'
    report += '\n\n'.join(sections) if sections else 'No failure details found. See the individual steps and uploaded logs.'
    directory.mkdir(parents=True, exist_ok=True)
    (directory / 'diagnostics.md').write_text(report + '\n')
    if os.environ.get('GITHUB_STEP_SUMMARY'):
        with open(os.environ['GITHUB_STEP_SUMMARY'], 'a') as stream:
            stream.write(report + '\n')
    for message in unique[:20]:
        print(f'::error title=Apple build/test diagnostic::{annotation(message[:1600])}')
    # Reporting never replaces or masks the original build/test exit code.


if __name__ == '__main__':
    main()
