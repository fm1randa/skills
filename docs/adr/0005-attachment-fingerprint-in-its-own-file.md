# Attachment fingerprint in its own file

The attachment fingerprint, the record of which attachments the Reminder hook has asked the Agent to read, lives in `sessions/<session-id>.asked`, a plain-text file that only `remind.sh` writes. It used to be an `attachmentsRequestedFor` key inside the Session Lock, which `remind.sh` merged in with a read, a compare and a rename, while `lock.sh` and Aidiom replaced the same file whole to pin a profile. A pin that landed between the hook's compare and its rename was lost. With one writer per file there is no race to narrow, and "no lock file means the session follows the Default Profile" holds literally, because the hook no longer creates lock files for inheriting sessions.

A pin never touches the fingerprint. The fingerprint holds the profile id, so a switch to another profile no longer matches it and the hook asks for the new attachments on the next turn; pinning the profile a session already uses does not ask again.

## Considered Options

- **Keep the key in the lock and narrow the compare-and-swap window.** The window can be made small but not closed without a lock primitive that bash and Swift share, which a stock macOS lacks (see ADR 0004).
- **Have every pin delete the fingerprint.** That keeps two writers on the fingerprint and makes every client of the contract responsible for a key it does not use.

## Consequences

The file contract of ADR 0003 changes shape: the Session Lock no longer carries the fingerprint, and the state root holds one more file per session that has been asked to read attachments. A lock written before this change may still hold `attachmentsRequestedFor`; the hook reads it only while the session has no `.asked` file, so such a session is not asked twice, and every other reader ignores it. Pruning covers `.asked` files with the same seven-day rule as locks.
