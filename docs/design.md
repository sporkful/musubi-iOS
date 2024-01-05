# Design doc

## Inspirations and design considerations

### Git + GitHub

#### Git

Git is a popular distributed version control system commonly used in software engineering.

"Repositories" are the unit of version control under Git. Git tracks changes made within a repository and does not track changes made across different repositories. By default, Git repositories can't be nested.

At a high level, a Git repository's internal model is a directed acyclic graph of "commits" (i.e. version snapshots) linked by hashing, such that each commit "points to" one or more parent commits from which it was derived. This results in a well-defined causally-ordered history.

Each collaborating device locally stores its own copy of the entire history DAG. History is represented as a DAG, not linearly i.e. a linked-list, since histories are allowed to "diverge". This is part of the tradeoff for defining "commit" as an "optimistic" operation (in the sense of optimistic concurrency control) that can complete locally without needing to block / coordinate with other collaborating devices.

Diverged history can be reconciled with a "merge" operation, which creates a new commit with more than one parent. A merge is said to have "conflicts" if the divergent (i.e. logically "concurrent" wrt causal order) branches-to-be-merged made different changes (wrt their lowest common ancestor in the DAG) in such a way that the VCS can't automatically determine the desired merged result. E.g. concurrent+differing changes to the same line in the same file would be marked as a conflict in Git. Under this definition, conflicts can only be resolved manually by users (who have a level of semantic understanding of the content that the VCS doesn't), and a merge can't complete until all conflicts are resolved.

#### GitHub

GitHub is a third-party service that hosts a highly-available central copy of any Git repository that users "push" to GitHub. Instead of needing to sync/backup in a peer-to-peer manner, users can just sync/backup against GitHub.

#### Adapting the Git+GitHub model for Musubi

To allow users to collaborate on and subscribe to specific playlists, Musubi version-controls each playlist separately. In Git terms, Musubi treats each playlist as a separate repository. When multiple users collaborate on the same playlist, that playlist is considered as a single logical repository, with each collaborator having their own clone of the repository.

Musubi's UI and underlying merge algorithm are co-designed to make the merging process both safe and intuitive for users. When merging divergent branches, Musubi always lets users manually (de)select which changes to keep; by default, all changes are selected. Notably, while most version control systems can only identify changes as independent *insert*s and *delete*s, Musubi can further identify *reorder*s/*move*s for easier conflict resolution (note for context: Spotify lets users manually define a "custom order" of songs within a playlist).
- TODO: describe this in separate impl doc.
    - 3-way merge between lowest common ancestor (LCA), branch A, branch B.
    - Associate each element in LCA.list with a "position" (within a uniquely-dense total ordering).
        - Assume Spotify playlists are not too large (most are < 500 songs, max is 10000), so for the initial prototype just use fractional indexing. Could upgrade later to something like the Fugue algorithm to generalize + guarantee noninterleaving.
    - Three sections of user-selectable changes
        1. Existing elements in LCA.list that were moved or removed by A or B (or both).
        2. New elements inserted by A into LCA.list.
        3. New elements inserted by B into LCA.list.

However, even with the ergonomic improvements described above, large diffs fundamentally can still be hard to deal with, especially given limited screen sizes on mobile devices. To help mitigate this, Musubi warns users if the change they are about to make can result in diverged history. This warning is best-effort; in particular, false negatives may occur - note that enforcing zero false negatives would be the equivalent of enforcing linearizability, which loses the availability guarantees of Git's distributed model.
- TODO: describe how this warning is implemented in separate impl doc.
    - Note this can be seen as a broken/leaky/best-effort locking scheme that achieves efficiency by sacrificing full synchronization (multiple devices can simultaneously "hold the lock") / deferring safety to a later merge operation.
    - In this context, all clocks/timestamps are physical and not synchronized across devices. Let D be an arbitrary user device, H be MusubiHub, and P be an arbitrary playlist.
    0. D syncs (its local clone of) P against H and updates its local D.P.last_sync_timestamp.
    1. D wants to make a change to P (i.e. user made action in UI).
        - D fetches remote H.P.last_modified_timestamp (store this in DynamoDB).
            - If fetch fails, trigger warning.
        - If H.P.last_modified_timestamp > D.P.last_sync_timestamp, trigger warning.
    2. If no warning is triggered OR user dismisses warning, apply the change (equivalent of modifying + "staging" in Git) and update remote H.P.last_modified_timestamp.
    3. On subsequent changes: No need to perform any more remote reads/writes (to H.P) since subsequent accesses don't give D any new information.

TODO: Give option to do user-library-level snapshots? This can capture inter-playlist dependencies. Note that this is essentially nesting Git repos, which can get complicated especially if the same user has multiple devices that they concurrently edit.

### Change data capture (CDC)

