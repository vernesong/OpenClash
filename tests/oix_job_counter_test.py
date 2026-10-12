"""Run from the repository root: python3 tests/oix_job_counter_test.py.

Run production shell counter functions in an isolated temporary directory.
No real services are invoked; flock is stubbed, so this is not a contention test.
"""
from pathlib import Path
import os
import subprocess
import tempfile

root = Path(__file__).resolve().parents[1]
ps_path = root / 'luci-app-openclash/root/usr/share/openclash/openclash_ps.sh'
core_path = root / 'luci-app-openclash/root/usr/share/openclash/openclash_core.sh'
source = ps_path.read_text()
with tempfile.TemporaryDirectory(prefix='openclash-job-fixture-') as temp:
    work = Path(temp)
    service = work / 'service'
    service.write_text('#!/bin/sh\nprintf "%s\\n" "$*" >> "$TEST_RESTART_LOG"\n')
    service.chmod(0o700)
    # Preserve the actual counter functions; isolate only dependency loading,
    # filesystem locations, and the service executable from the router.
    source = source.replace('. $IPKG_INSTROOT/usr/share/openclash/uci.sh', ':')
    source = source.replace('/tmp/openclash_jobs', str(work / 'jobs'))
    source = source.replace('/tmp/lock/openclash_jobs.lock', str(work / 'jobs.lock'))
    source = source.replace('/etc/init.d/openclash restart', str(service) + ' restart')
    helper = work / 'helper.sh'
    helper.write_text(source)
    fixture = r'''
set -eu
. "$TEST_HELPER"
# Files are isolated; exercise the queue state without host flock requirements.
flock() { :; }
unify_ps_prevent() { echo 0; }
expect_state() { [ "$(cat "$JOB_COUNTER_FILE")" = "$1" ] || { echo "unexpected queue state" >&2; exit 1; }; }
expect_no_restart() { wait; [ ! -e "$TEST_RESTART_LOG" ]; }
# Another updater finishes while this install-only job remains active.
inc_job_counter
inc_job_counter
expect_state '2 0'
dec_job_counter_and_restart 1
expect_state '1 1'
expect_no_restart
dec_job_counter_and_restart 0 1
expect_state '0 1'
expect_no_restart
# The saved request is consumed normally by a later ordinary job.
inc_job_counter
expect_state '1 1'
dec_job_counter_and_restart 0
wait
[ "$(cat "$TEST_RESTART_LOG")" = restart ]
[ ! -e "$JOB_COUNTER_FILE" ]
rm "$TEST_RESTART_LOG"
# The install-only error path has the same suppression contract.
printf '1 1\n' > "$JOB_COUNTER_FILE"
dec_job_counter_and_restart 0 1
expect_state '0 1'
expect_no_restart
# A direct request can be recorded while execution is suppressed.
printf '1 0\n' > "$JOB_COUNTER_FILE"
dec_job_counter_and_restart 1 1
expect_state '0 1'
expect_no_restart
# Normal no-restart jobs and active-service protection retain their semantics.
printf '1 0\n' > "$JOB_COUNTER_FILE"
dec_job_counter_and_restart 0
expect_state '0 0'
expect_no_restart
unify_ps_prevent() { echo 1; }
printf '1 1\n' > "$JOB_COUNTER_FILE"
dec_job_counter_and_restart 0
expect_state '0 1'
expect_no_restart
printf 'PASS: real job-counter functions, six queue/restart scenarios\n'
'''
    env = dict(os.environ, TEST_HELPER=str(helper), TEST_RESTART_LOG=str(work / 'restarts'))
    subprocess.run(['bash', '-c', fixture], check=True, env=env)
    calls = [line.strip() for line in core_path.read_text().splitlines() if line.strip().startswith('dec_job_counter_and_restart ')]
    assert len(calls) == 2
    assert all(line.endswith('"${OIX_INSTALL_ONLY:-0}"') for line in calls)
    print('PASS: both installer completion and early-error paths forward install-only suppression')
