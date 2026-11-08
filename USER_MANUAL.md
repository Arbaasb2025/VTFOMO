# VT FOMO — Roles and User Manual

Updated November 8, 2026

## 1. The concept

VT FOMO has four main roles: **Student**, **Organizer**, **Area Coordinator**, and
**Administrator**. Organizers have two categories: **Student Leader (SL)** and
**Authorized Organizer**.

An approval is an ongoing permission to publish, not approval for just one event.
An approved organizer can publish any number of events within their scope until
their approval is revoked. Each event does not need a fresh approval. There is
currently no automatic expiration date or separate event-review queue.

| Role | What they can do | Who controls their access |
|---|---|---|
| Student | Browse events, save events, and request organizer approval | Normal account registration |
| Student Leader (SL) | Publish public events and events restricted to their approved residence hall; edit their own events | Their area's coordinator or an admin |
| Authorized Organizer | The same publishing permissions, with a university group/team affiliation recorded during approval; post for a partner or charity | Their area's coordinator or an admin |
| Area Coordinator | Review both organizer categories, approve or decline requests, revoke approval, and publish within their area | Admin assigns or removes the coordinator's area |
| Admin | Review organizers across every area, manage coordinators, and edit or delete any event | Explicitly allowed email AND a separately provisioned admin account |

SL and Authorized Organizer are two categories of organizer, not two levels of
power. Both must be approved. An affiliation name or organization membership by
itself never grants publishing permission. One active organizer category is stored
per account in this version.

## 2. Demo accounts

These are accounts inside the VT FOMO app. Creating the admin account does not
create or change a Gmail account.

**Demo password for all five accounts: `Hokies2026`**

| Email | Initial access |
|---|---|
| `arbaasb@gmail.com` | Administrator |
| `cord@vt.edu` | Area Coordinator for Upper Quad |
| `org@vt.edu` | Pending Authorized Organizer request for Pritchard Hall, affiliation “Demo university team” |
| `sl@vt.edu` | Pending Student Leader request for Pritchard Hall |
| `stu@vt.edu` | Student, Pritchard Hall |

The two pending organizer accounts initially have student permissions. Their
publishing controls become available after approval. The five accounts are added
when running a Debug build from Xcode. Existing accounts with these addresses are
preserved; setup does not replace passwords or silently promote an existing user.
Existing older demo accounts are also preserved.

The shared demo password and local admin account are for coursework demonstrations,
not deployment to real users. Regular registration remains restricted to `@vt.edu`
and always creates a student account. It does not offer an admin role selector.

## 3. Student: request organizer access

1. Sign in, then open **Profile**.
2. Check your **Residence hall**. Use **Change hall** if needed.
3. Under **Organizer access**, choose **Student Leader (SL)** or
   **Authorized Organizer**.
4. For Authorized Organizer, enter your university group or team. This is a
   claim for the reviewer to verify, not automatic proof of affiliation.
5. Select **Request organizer approval**.
6. Your profile shows that approval is pending. You cannot publish yet.

If a request is declined, the profile displays feedback. Contact your coordinator
before submitting again. If you need to switch an already approved organizer type,
have the coordinator revoke the current approval, then request the new category.

## 4. Area Coordinator: approve or decline

1. Sign in as `cord@vt.edu`.
2. Open **Profile → Review organizer requests**.
3. Under **Pending requests**, inspect the person's email, organizer type,
   residence hall, and affiliation, where supplied.
4. Verify their SL appointment or university/team authorization outside the app.
5. Choose **Approve** or **Decline**.

Approved people appear under separate **Student Leader (SL)** and
**Authorized Organizer** sections. Approval records the approving account, time,
hall, and organizer category.

Coordinators only see and manage requests for their own residential area. For
example, the Upper Quad coordinator cannot approve someone for a Central-area
hall. Admins can review all areas.

## 5. Organizer: publish an event

After approval, sign in to the organizer account and use the event creation control
on the Map or Events screen.

1. Enter the title, description, category, time, and location.
2. Optionally fill **On behalf of (optional charity or partner)**.
3. Choose visibility:
   - **Public:** everyone can see the event.
   - **Specific Halls:** only residents of selected halls can see it; an organizer
     can select only their approved residence hall.
4. Publish. Your approval remains valid for subsequent events.

**Charity example:** a charity asks your university team to advertise a fundraiser.
An approved SL or Authorized Organizer creates the event and enters the charity's
name in “On behalf of.” The event retains the posting person's account as its
organizer. The charity does not need an account or gain publishing rights.

In this version, the approved account must have a selected residence hall, and
its hall permission is tied to that hall. Authorized Organizer does not mean
unrestricted access to every hall. Public visibility and hall-specific publishing
are separate choices.

## 6. Remove an SL or organizer: revoke approval

1. As the area's coordinator or an admin, open **Review organizer requests**.
2. Find the person in the appropriate approved organizer section.
3. Choose **Revoke approval** and confirm.

Revocation returns the person to **student** permissions. They can still browse
and save events, but cannot publish new events or edit existing ones. Permissions
are checked again when saving, so an editor opened before revocation cannot be
used to publish afterward. A fresh request and approval are needed to regain access.

Existing events stay visible; revocation does not delete them automatically. An
admin can review and edit or delete those events under **Manage all events**.

Changing residence halls does not transfer approval to the new hall. The original
approval remains tied to its hall and is unusable while the residence differs;
returning to the original hall restores its use unless the grant was revoked.
For someone who has actually lost their appointment, **revoke their approval**—do
not rely only on changing their residence hall.

## 7. Administrator controls

Sign in as `arbaasb@gmail.com`, then open **Profile**.

### Manage organizer access

Use **Review organizer requests** to approve, decline, or revoke either organizer
category across all residential areas.

### Assign or remove coordinators

1. Open **Manage coordinators**.
2. Search for the person's name or email.
3. Choose **Assign coordinator area**, pick an area, and confirm.
4. To remove their authority, choose **Remove coordinator access** and confirm.

Removing coordinator access returns the account to student permissions. Assigning,
reassigning, or removing a coordinator clears old organizer approvals and pending
requests, avoiding accidental permission carryover.

The coordinator's removal does not automatically revoke organizers they previously
approved. An admin or replacement coordinator can review and revoke those grants.

### Moderate events

Open **Manage all events**, select an event, then **Edit** to update it. The event
editor also offers **Delete Event**, with confirmation. Admin edits preserve the
original organizer account.

### Admin access is deliberately separate

The current email allowlist contains `arbaasb@gmail.com`. The account must also be
explicitly provisioned with the admin role. Merely entering that email in a form
does not grant admin access. The coordinator-management screen cannot create or
remove admin accounts. Additional admins require a deliberate configuration and
provisioning change by the project owner.

“Admin control” here covers organizer approvals, coordinator assignments, and
event moderation. Account deletion, password resets, invitation emails, automatic
approval expiration, and a full audit-history screen are not implemented.

## 8. Returning users: Face ID

1. Log in with a password once on this installation.
2. Log out or close and reopen the app.
3. Choose **Use Face ID as …** and complete the system prompt.
4. If biometrics are unavailable or fail, use your email and password.

Touch ID devices show Touch ID instead. Canceling a biometric prompt leaves you
signed out. **Forget this account on this device** removes the remembered-account
shortcut. Face ID authenticates the remembered account; it never grants organizer,
coordinator, or admin permissions.

The iPhone simulator needs simulated biometric enrollment and a matching face
result to demonstrate this. The final real-device scan still needs device testing.

## 9. Important prototype boundary

Accounts, requests, approvals, and events currently use local SwiftData storage.
Demonstrate switching roles on the **same simulator or phone installation**. An
approval on one phone does not yet reach another phone.

Before real deployment, the shared backend must verify email ownership, manage
secure sessions, enforce roles and revocation on the server, and replace debug
accounts and shared demo passwords. The local checks here are not a substitute
for server authorization.

## 10. Suggested demonstration

1. Run a Debug build from Xcode to add the five accounts.
2. Sign in as `sl@vt.edu`: confirm the request is pending and publishing is blocked.
3. Sign in as `cord@vt.edu`: approve the SL and Authorized Organizer requests.
4. Sign in as `sl@vt.edu`: publish a public event and a Pritchard-only event.
5. Sign in as `org@vt.edu`: publish a charity event using “On behalf of.”
6. Sign in as the coordinator: revoke the SL's approval.
7. Sign in as the SL again: confirm student access and no publishing permission.
8. Sign in as the admin: review events, then assign or remove coordinator access.
9. Relaunch: confirm that revoked permissions stay revoked.
10. Test Face ID success, cancellation, and password fallback.

## 11. Updated sign-in screen

The opening screen keeps email, password, and the returning-user biometric shortcut
in one compact layout. Tap **Sign-in help & demo accounts** for demo accounts and
simulator instructions. Choosing an account fills the form and closes the sheet;
press **Log In** to sign in.

If Face ID is unavailable, use **Check biometric availability**. The simulator
sends a simulated result; it does not scan your face with the Mac camera.
Apple's system authentication interface controls the prompt and animation.

The interface includes button press feedback, screen entrance transitions,
animated filter selection, and animated save/reminder changes. New motion effects
respect the system Reduce Motion setting.
