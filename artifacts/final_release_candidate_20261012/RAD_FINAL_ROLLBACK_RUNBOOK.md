# Rollback planning

Do not use a destructive database reset or blind migration-history edit. Before deployment, the DBA must capture a restorable off-machine backup and object-level before/after diff. For a failed cutover, stop traffic-changing rollout, preserve evidence, and use the rehearsed restoration/forward-fix decision signed by the owner. Consultation RPC and Storage policy changes require a staged compatibility check with the Flutter client. No production rollback action occurred.
