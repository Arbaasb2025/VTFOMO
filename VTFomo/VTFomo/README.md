# VT FOMO

Every event on campus, on one map.

iOS/iPadOS app for CS 3714. Students see campus events as pins on a map of
Virginia Tech, with their own residence hall's events highlighted. RAs, SLs,
and club officers publish events, and can restrict an event so only certain
halls can see it.

## Organizer approvals

In **Profile → Hall organizer access**, residents request approval for their
selected residence hall. An Area Coordinator opens **Profile → Review organizer
requests** to approve or decline requests within their managed area, or revoke an
existing approval. Approval records the hall, approver, and time. Changing halls
does not transfer approval. The event editor checks permissions again on save.
Existing organizer roles need approval for hall publishing after this update;
organization membership alone does not grant publishing access. Both organizer types need approval.

This prototype stores accounts, requests, and approvals locally with SwiftData.
To demonstrate the workflow, switch accounts on the same installation. A shared
backend must enforce these rules for use across phones.

### Quick acceptance check

1. Sign in as the demo student `robertk@vt.edu`, open Profile, and request approval
   for Pritchard Hall. No publishing access should be granted yet.
2. Log out and sign in as `dmorales@vt.edu` (Upper Quad Area Coordinator).
   Open organizer requests and approve Robert. Requests from Central or East
   must not appear in this coordinator's list.
3. Sign back in as Robert and publish a Pritchard hall event. Changing residence
   to a different hall must remove hall publishing access until new approval.
4. Revoke Robert's approval as the coordinator. Robert must no longer be able to
   publish hall events, including from an editor opened before revocation.

All seeded demo accounts use the password displayed on the login screen.

## Returning-user Face ID

Sign in with a password once on the device. After logout or a cold launch, choose
**Face ID · Log in as …** to authenticate the remembered account. Devices with
Touch ID show the appropriate label. Password login remains available when
biometrics are unavailable, fail, or lock out. Canceling authentication leaves the
user signed out. **Forget this account on this device** removes the shortcut.

The app uses Apple's biometric prompt and does not collect face images. The
local prototype remembers an account ID; a future backend should use protected
session credentials rather than treating a local account ID as server identity.

For simulator checks, enable biometric enrollment and simulate matching and
nonmatching faces. Also verify cancellation, logout, relaunch, password fallback,
and forgetting the account. Verify the actual scan on a Face ID device before
submission.

See `USER_MANUAL.md` at the project root for the role matrix, demo accounts, approvals, revocation, and admin workflows.
