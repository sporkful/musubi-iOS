# Design doc

## Inspirations and design considerations

### Git + GitHub

#### Git

Git is a popular distributed version control system commonly used in software engineering.

"Repositories" are the unit of version control under Git. Git tracks changes made within a repository and does not track changes made across different repositories.

Multiple *physical* "clones" can be made of the same *logical* repository. Changes can be made/logged on each clone without needing to *coordinate with* / *block on* / *wait for* other clones. Divergent threads of change can be "merged" at a later time to reflect a true/consistent state of the logical repository. This enables collaborators on different physical devices to work asynchronously.

Changes in Git are represented as "commits", which are point-in-time snapshots of a repository's content. Creating a commit is a *non-blocking* manual operation available to each clone of the repository. A Git repository's *global logical history* is represented as a *directed acyclic graph* of commits linked by hashing, such that each commit points to one or more parent commits from which it was derived. The DAG can *fork*[^1] when different clones concurrently make their own commits derived from the same parent commit. The DAG can also *join* when concurrent (threads of) commits are "merged" into a single consistent state - this is represented by a new commit with multiple parents.

[^1]: The term *fork* (and *join*) is used here to describe a mental model for how a Git repository's global history flows as a DAG / to explain why history is not just represented as a linked-list (or tree). This usage of the term *fork* is related to but **should not be conflated with ["forking" in GitHub](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks)**. This is also related to but not exactly the same as "branching" in Git - "branching" is a physical/local construct while *forking* (as used here) is a logical/global concept.

Each clone of a repository holds its own physical copy of the repository's global logical history DAG. These physical copies may be incomplete due to the distributed/non-blocking nature of Git - each clone will need to manually/periodically "fetch" new commits it's interested in from other clones (aka "remotes").

To physically organize logical threads of commits that are concurrent, Git provides the "branch" construct - a branch is essentially just a named reference to the commit representing the "head" of a logical thread. In particular, each clone maintains "remote branches" that track the progress of other clones. A great explanation of remote branches can be found [here](https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches). **Note that for simplicity of use, Musubi does not allow multiple *logical* branches. In other words, every Musubi repository clone only has a "main" branch and associated "\[remote\]/main" branch(es), no things like "feature" branches. The concept of branching is ultimately abstracted away from the user, again for simplicity.**

As mentioned earlier, concurrent commits (often the heads of concurrent logical threads) can be "merged" into a single consistent state - this is represented by a new commit with multiple parents. A merge is said to have "conflicts" if the commits-to-be-merged made different changes (wrt their lowest common ancestor in the global logical history DAG) in such a way that the VCS can't automatically determine the desired merged result. E.g. concurrent+differing changes to the same line in the same file would be marked as a conflict in Git. Under this definition, conflicts can only be resolved manually by users (who have a level of semantic understanding of the content that the VCS doesn't), and a merge can't complete until all conflicts are resolved.

#### GitHub

GitHub is a third-party service that hosts a highly-available clone of any Git repository that users "push" to GitHub. Instead of needing to sync/backup in a peer-to-peer manner, users can just sync/backup against GitHub.

Crucially, GitHub facilitates the ["Integration-Manager Workflow"](https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows#wfdiag_b), which Musubi adopts.

#### Adapting the Git+GitHub model for Musubi

TODO:
- staging area = Musubi
- "local" repo = Musubi cloud services
    - every commit must go to cloud before "succeeding"
    - this simplifies things so users don't have to think about committing, pushing, and pull-requesting/merging.
    - also enables ergonomic improvements to process?
    - HOWEVER makes Musubi explicitly NOT local-first :(
        - but Musubi can't be local-first anyways because it's pretty useless without connection to Spotify API.
    - TODO: how to handle conflicts between multiple Musubi devices for same user??
- GitHub main repo = Musubi cloud services + original playlist on Spotify with single owner (creator).
- GitHub fork = Musubi cloud services + independent Spotify playlist copy
    - but editing directly on Spotify is NOT like editing directly on GitHub since cloud services won't know what changes you made to Spotify until you initiate a push/merge.


To allow users to collaborate on and subscribe to specific playlists, Musubi version-controls each playlist separately, i.e. each playlist is a separate "repository". When multiple users collaborate on the same playlist, that playlist is considered as a single logical repository, with each collaborator having their own clone of the repository.

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

