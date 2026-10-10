"""Disposable Windows audit for original T01 PowerShell helpers; no application tests."""
from __future__ import annotations
import argparse, copy, hashlib, json, os, pathlib, shutil, subprocess, sys, tempfile

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--bundle-root', required=True, type=pathlib.Path)
parser.add_argument('--git', default=shutil.which('git'), type=pathlib.Path)
parser.add_argument('--powershell51', default=pathlib.Path(os.environ.get('SystemRoot', 'C:/Windows')) / 'System32/WindowsPowerShell/v1.0/powershell.exe', type=pathlib.Path)
parser.add_argument('--powershell7', default=shutil.which('pwsh'), type=pathlib.Path)
parser.add_argument('--output-dir', type=pathlib.Path)


def fake_git():
    args = sys.argv[2:]
    if len(args) < 3 or args[0] != '--no-optional-locks' or args[1] != '-C':
        print('Unexpected controlled fixture Git invocation', file=sys.stderr)
        return 97
    key = ' '.join(args[3:])
    with pathlib.Path(os.environ['T01_FIXTURE_CALLS']).open('a') as log:
        log.write(json.dumps(key) + '\n')
    response = json.loads(pathlib.Path(os.environ['T01_FIXTURE_RESPONSES']).read_text()).get(key)
    if response is None:
        print('Unexpected controlled fixture Git operation', file=sys.stderr)
        return 98
    sys.stdout.write(response.get('stdout', ''))
    sys.stderr.write(response.get('stderr', ''))
    return response.get('exit', 0)

if len(sys.argv) > 1 and sys.argv[1] == '--fake-git':
    raise SystemExit(fake_git())
OPTIONS = parser.parse_args()
if OPTIONS.git is None or OPTIONS.powershell7 is None:
    parser.error('git and pwsh must be on PATH or passed explicitly')
HERE = OPTIONS.output_dir.resolve() if OPTIONS.output_dir else pathlib.Path(tempfile.mkdtemp(prefix='AudioFileForPhone-T01-helper-audit-'))
HERE.mkdir(parents=True, exist_ok=True)
BUNDLE = OPTIONS.bundle_root.resolve()
PYTHON = pathlib.Path(sys.executable)
GIT = OPTIONS.git.resolve()
SHELLS = {'WindowsPowerShell51': OPTIONS.powershell51.resolve(), 'PowerShell7': OPTIONS.powershell7.resolve()}
IMPORTER = BUNDLE / 'tools/Import-CodexBundle.ps1'
SYNC = BUNDLE / 'repo-overlay/docs/codex-v1/tools/Test-GitSync.ps1'
MANIFEST = json.loads((BUNDLE / 'IMPORT_MANIFEST.json').read_text())
URL = 'https://github.com/PikkuJanne/AudioFileForPhone.git'
SHA, OTHER = 'a' * 40, 'b' * 40
results = []

def proc(args, *, env=None, cwd=None):
    return subprocess.run([str(x) for x in args], env=env, cwd=cwd, text=True, capture_output=True, timeout=45)

def git(repo, *args):
    p = proc([GIT, '-C', repo, *args])
    if p.returncode != 0:
        raise AssertionError(f'Fixture git {args} failed: {p.stdout} {p.stderr}')
    return p.stdout.strip()

def snapshot(repo):
    return {p.relative_to(repo).as_posix(): (hashlib.sha256(p.read_bytes()).hexdigest(), p.stat().st_mtime_ns)
            for p in repo.rglob('*') if p.is_file()}

def fresh(parent, name):
    repo = parent / name
    repo.mkdir()
    git(repo, 'init', '--initial-branch=main')
    git(repo, 'config', 'user.name', 'Disposable T01 Fixture')
    git(repo, 'config', 'user.email', 'fixture@example.invalid')
    git(repo, 'config', 'core.autocrlf', 'false')
    git(repo, 'remote', 'add', 'origin', URL)
    (repo / 'AudioFileForPhone.ps1').write_text('# disposable application sentinel\n')
    git(repo, 'add', 'AudioFileForPhone.ps1')
    git(repo, 'commit', '-m', 'Fixture seed')
    return repo

def commit(repo):
    git(repo, 'add', '--all')
    git(repo, 'commit', '-m', 'Fixture state')

def run_script(shell, script, repo, *extra, env=None):
    task_env = os.environ.copy()
    task_env['PATH'] = str(GIT.parent) + os.pathsep + task_env.get('PATH', '')
    task_env['GIT_TERMINAL_PROMPT'] = '0'
    if 'WindowsPowerShell' in str(shell):
        task_env['PSModulePath'] = str(pathlib.Path(os.environ['SystemRoot']) / 'System32/WindowsPowerShell/v1.0/Modules')
    if env:
        task_env.update(env)
    command = [shell, '-NoLogo', '-NoProfile', '-NonInteractive', '-ExecutionPolicy', 'RemoteSigned', '-File', script, '-RepoPath', repo, *extra]
    return proc(command, env=task_env, cwd=repo)

def check(label, shell_name, operation):
    try:
        details = operation()
        results.append({'shell': shell_name, 'case': label, 'status': 'pass', **(details or {})})
        print('PASS', shell_name, label, flush=True)
    except Exception as exc:
        results.append({'shell': shell_name, 'case': label, 'status': 'fail', 'reason': str(exc)})
        print('FAIL', shell_name, label, str(exc), flush=True)

def require(p, code, text=''):
    assert p.returncode == code, f'Exit {p.returncode}, expected {code}: {p.stdout} {p.stderr}'
    if text:
        assert text in p.stdout + p.stderr, f'Expected {text!r}: {p.stdout} {p.stderr}'

def importer_cases(shell_name, shell, parent):
    def preview_apply_identical():
        repo = fresh(parent, 'preview-apply-identical')
        before = snapshot(repo)
        p = run_script(shell, IMPORTER, repo)
        require(p, 0, 'Preview only')
        assert snapshot(repo) == before, 'Preview changed file or Git bytes/timestamps'
        p = run_script(shell, IMPORTER, repo, '-Apply')
        require(p, 0, 'Planning files imported')
        app = repo / 'AudioFileForPhone.ps1'
        assert app.read_text() == '# disposable application sentinel\n'
        additions = set(snapshot(repo)) - set(before)
        expected = {x['target'] for x in MANIFEST['files']}
        assert additions == expected, f'Unexpected additions: {additions ^ expected}'
        for item in MANIFEST['files']:
            assert (repo / item['target']).read_bytes() == (BUNDLE / item['source']).read_bytes()
        commit(repo)
        identical_before = snapshot(repo)
        p = run_script(shell, IMPORTER, repo, '-Apply')
        require(p, 0, 'Identical')
        assert snapshot(repo) == identical_before, 'Identical rerun changed bytes/timestamps'
        return {'preview_writes': 0, 'created_allowlisted_files': len(expected), 'identical_rerun_writes': 0}
    check('A02_preview_additive_apply_identical', shell_name, preview_apply_identical)

    def conflict():
        repo = fresh(parent, 'conflict')
        (repo / 'AGENTS.md').write_text('Existing owner guidance\n')
        commit(repo)
        before = snapshot(repo)
        require(run_script(shell, IMPORTER, repo), 0, 'Conflict')
        assert snapshot(repo) == before
        require(run_script(shell, IMPORTER, repo, '-Apply'), 1, 'Conflicting files exist')
        assert snapshot(repo) == before
    check('A02_conflict_atomic_preflight_refusal', shell_name, conflict)

    def skip_agents():
        repo = fresh(parent, 'skip-agents')
        (repo / 'AGENTS.md').write_text('Existing manually merged owner guidance\n')
        commit(repo)
        require(run_script(shell, IMPORTER, repo, '-Apply', '-SkipAgents'), 0)
        assert (repo / 'AGENTS.md').read_text() == 'Existing manually merged owner guidance\n'
        assert len([p for p in (repo / 'docs/codex-v1').rglob('*') if p.is_file()]) == 61
    check('A02_skip_agents_preserves_guidance', shell_name, skip_agents)

    def dirty():
        repo = fresh(parent, 'dirty')
        (repo / 'existing-user-work.txt').write_text('fixture only\n')
        before = snapshot(repo)
        require(run_script(shell, IMPORTER, repo, '-Apply'), 1, 'clean checkout')
        assert snapshot(repo) == before
    check('A02_dirty_apply_refused', shell_name, dirty)

    for mode in ['fetch', 'push', 'not-git', 'subdirectory']:
        def wrong(mode=mode):
            repo = fresh(parent, 'wrong-' + mode)
            if mode == 'fetch':
                git(repo, 'remote', 'set-url', 'origin', 'https://github.com/Other/Other.git')
            elif mode == 'push':
                git(repo, 'remote', 'set-url', '--push', 'origin', 'https://github.com/Other/Other.git')
            elif mode == 'not-git':
                repo = parent / 'ordinary-non-git-directory'
                repo.mkdir()
            else:
                repo = repo / 'nested'
                repo.mkdir()
            before = snapshot(repo)
            require(run_script(shell, IMPORTER, repo, '-Apply'), 1)
            assert snapshot(repo) == before
        check('A02_wrong_' + mode + '_refused', shell_name, wrong)

    def reparse():
        repo = fresh(parent, 'reparse-target')
        (repo / '.gitignore').write_text('docs/\n')
        commit(repo)
        target = parent / 'junction-target-sentinel'
        target.mkdir()
        (target / 'sentinel.txt').write_text('Disposable target must remain untouched\n')
        command = "$null = New-Item -ItemType Junction -Path '" + str(repo / 'docs').replace("'", "''") + "' -Target '" + str(target).replace("'", "''") + "'"
        require(proc([shell, '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', command]), 0)
        assert git(repo, 'status', '--porcelain=v1', '--untracked-files=all') == ''
        target_before = snapshot(target)
        require(run_script(shell, IMPORTER, repo, '-Apply'), 1, 'reparse-point')
        assert snapshot(target) == target_before
        assert not (repo / 'AGENTS.md').exists(), 'Importer started creating before full reparse preflight'
    check('A02_junction_target_refused', shell_name, reparse)


def sync_cases(shell_name, shell, parent):
    fake = parent / 'controlled-git'
    fake.mkdir()
    (fake / 'git.cmd').write_text('@echo off\r\n"' + str(PYTHON) + '" -B "' + str(pathlib.Path(__file__).resolve()) + '" --fake-git %*\r\nexit /b %errorlevel%\r\n')
    repo = parent / 'sync-fixture-repo'
    repo.mkdir()
    baseline = {
        'remote get-url --all origin': {'stdout': URL + '\n'},
        'remote get-url --push --all origin': {'stdout': URL + '\n'},
        'symbolic-ref --quiet --short HEAD': {'stdout': 'codex/fixture\n'},
        'rev-parse --verify HEAD': {'stdout': SHA + '\n'},
        'status --porcelain=v1 --untracked-files=all': {'stdout': ''},
        'ls-remote --symref origin HEAD': {'stdout': 'ref: refs/heads/main\tHEAD\n' + OTHER + '\tHEAD\n'},
        'ls-remote --exit-code origin refs/heads/codex/fixture': {'stdout': SHA + '\trefs/heads/codex/fixture\n'},
        'ls-remote --exit-code origin refs/heads/main': {'stdout': OTHER + '\trefs/heads/main\n'},
    }
    response_path = parent / 'git-responses.json'
    call_path = parent / 'git-calls.jsonl'
    env = {'PATH': str(fake) + os.pathsep + os.environ.get('PATH', ''), 'T01_FIXTURE_RESPONSES': str(response_path), 'T01_FIXTURE_CALLS': str(call_path)}
    def execute(mapping, extra=()):
        response_path.write_text(json.dumps(mapping))
        call_path.write_text('')
        result = run_script(shell, SYNC, repo, '-AsJson', *extra, env=env)
        value = json.loads(result.stdout)
        calls = [json.loads(line) for line in call_path.read_text().splitlines()]
        return result, value, calls
    def clean():
        p, output, calls = execute(baseline)
        require(p, 0)
        assert output['status'] == 'pass' and output['active_branch_synchronized'] is True
        assert output['active_head_equals_main'] is False
        assert 'remote get-url --all origin' in calls and 'remote get-url --push --all origin' in calls
        return {'git_calls': len(calls), 'main_integration_claim': False}
    check('A03_clean_matching_task_branch', shell_name, clean)
    def main():
        mapping = copy.deepcopy(baseline)
        mapping['symbolic-ref --quiet --short HEAD']['stdout'] = 'main\n'
        mapping['ls-remote --exit-code origin refs/heads/main']['stdout'] = SHA + '\trefs/heads/main\n'
        p, output, calls = execute(mapping, ('-RequireMain',))
        require(p, 0)
        assert output['active_head_equals_main'] is True
    check('A03_clean_matching_main', shell_name, main)
    failures = {
        'dirty': ('status --porcelain=v1 --untracked-files=all', {'stdout': '?? disposable-user-work.txt\n'}),
        'detached': ('symbolic-ref --quiet --short HEAD', {'exit': 1, 'stderr': 'Fixture detached HEAD\n'}),
        'mismatched': ('ls-remote --exit-code origin refs/heads/codex/fixture', {'stdout': OTHER + '\trefs/heads/codex/fixture\n'}),
        'absent_ref': ('ls-remote --exit-code origin refs/heads/codex/fixture', {'exit': 2}),
        'network_failure': ('ls-remote --symref origin HEAD', {'exit': 128, 'stderr': 'Fixture network unavailable\n'}),
        'wrong_fetch': ('remote get-url --all origin', {'stdout': 'https://github.com/Other/Other.git\n'}),
        'wrong_push': ('remote get-url --push --all origin', {'stdout': 'https://github.com/Other/Other.git\n'}),
        'multiple_push': ('remote get-url --push --all origin', {'stdout': URL + '\n' + URL + '\n'}),
        'wrong_default': ('ls-remote --symref origin HEAD', {'stdout': 'ref: refs/heads/master\tHEAD\n' + OTHER + '\tHEAD\n'}),
        'duplicate_ref': ('ls-remote --exit-code origin refs/heads/codex/fixture', {'stdout': (SHA + '\trefs/heads/codex/fixture\n') * 2}),
        'malformed_ref': ('ls-remote --exit-code origin refs/heads/codex/fixture', {'stdout': 'badsha\trefs/heads/codex/fixture\n'}),
    }
    for name, (command, response) in failures.items():
        def failure(command=command, response=response):
            mapping = copy.deepcopy(baseline)
            mapping[command] = response
            p, output, calls = execute(mapping)
            require(p, 1)
            assert output['status'] == 'fail'
        check('A03_' + name + '_refused', shell_name, failure)
    def requiremain():
        p, output, calls = execute(baseline, ('-RequireMain',))
        require(p, 1)
        assert output['status'] == 'fail'
    check('A03_require_main_refuses_task_branch', shell_name, requiremain)


def main():
    versions = {}
    for shell_name, shell in SHELLS.items():
        version = proc([shell, '-NoLogo', '-NoProfile', '-NonInteractive', '-Command', '$PSVersionTable.PSVersion.ToString()'])
        require(version, 0)
        versions[shell_name] = version.stdout.strip()
        print('SHELL', shell_name, versions[shell_name], flush=True)
        parent = pathlib.Path(tempfile.mkdtemp(prefix='fixtures-' + shell_name + '-', dir=HERE))
        importer_cases(shell_name, shell, parent)
        sync_cases(shell_name, shell, parent)
    record = {'shell_versions': versions, 'bundle_source': 'original extracted bundle', 'scope': 'Original PowerShell helper behavior on disposable fixtures only; no application or Music/phone testing; controlled Git responses do not prove live remote synchronization.', 'results': results}
    (HERE / 'windows-helper-audit-results.json').write_text(json.dumps(record, indent=2))
    print('SUMMARY', sum(r['status'] == 'pass' for r in results), 'passed;', sum(r['status'] != 'pass' for r in results), 'failed', flush=True)
    return 1 if any(r['status'] != 'pass' for r in results) else 0

if __name__ == '__main__':
    raise SystemExit(main())