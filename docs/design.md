# Design doc

## Inspirations and design considerations

### Git + GitHub

#### Git

Git is a popular distributed version control system commonly used in software engineering.

"Repositories" are the unit of version control under Git. Git tracks changes made within a repository and does not track changes made across different repositories.

Multiple *physical* "clones" can be made of the same *logical* repository. Changes can be made/logged on each clone without needing to coordinate with / block on / wait for other clones. Divergent threads of change can be "merged" at a later time to reflect a true/consistent state of the logical repository. This enables collaborators on different physical devices to work asynchronously.

Changes in Git are represented as "commits", which are point-in-time snapshots of a repository's content. Creating a commit is a non-blocking manual operation available to each clone of the repository. A Git repository's *global logical history* is represented as a directed acyclic graph of commits linked by hashing, such that each commit points to one or more parent commits from which it was derived. The DAG can *fork*[^1] when different clones concurrently make their own commits derived from the same parent commit. The DAG can also *join* when concurrent (threads of) commits are "merged" into a single consistent state - this is represented by a new commit with multiple parents.

[^1]: The term *fork* (and *join*) is used here to describe a mental model for how a Git repository's global history flows as a DAG / to explain why history is not just represented as a linked-list (or tree). The usage of the term *fork* here is related to but **should not be conflated with ["forking" in GitHub](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks)** (which we also discuss later in this document).

Each clone of a repository holds its own physical copy of the repository's global logical history DAG. These physical copies may be incomplete due to the distributed/non-blocking nature of Git - each clone will need to manually/periodically "fetch" new commits it's interested in from other clones (aka "remotes").

To physically organize logical threads of commits that are concurrent, Git provides the "branch" construct - a branch is essentially just a named reference to the commit representing the "head" of a logical thread. In particular, each clone maintains "remote branches" that track the progress of other clones. A great explanation of remote branches can be found [here](https://git-scm.com/book/en/v2/Git-Branching-Remote-Branches).

As mentioned earlier, concurrent commits (often the heads of concurrent logical threads) can be "merged" into a single consistent state - this is represented by a new commit with multiple parents. A merge is said to have "conflicts" if the commits-to-be-merged made different changes (wrt their lowest common ancestor in the global logical history DAG) in such a way that the VCS can't automatically determine the desired merged result. E.g. concurrent+differing changes to the same line in the same file would be marked as a conflict in Git. Under this definition, conflicts can only be resolved manually by users (who have a level of semantic understanding of the content that the VCS doesn't), and a merge can't complete until all conflicts are resolved.


#### GitHub / Integration-Manager Workflow (IMW)

GitHub is a third-party service that hosts a highly-available clone of any Git repository that users "push" to GitHub. Instead of needing to sync/backup in a peer-to-peer manner, users can just sync/backup against GitHub.

Crucially, GitHub facilitates the ["Integration-Manager Workflow (IMW)"](https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows#wfdiag_b), which Musubi also adopts.


#### Adapting the Git+IMW architecture for Musubi

Git(+GitHub/IMW) is an extremely flexible/powerful model that many successful large projects have been organized around. OTOH, Musubi has a much narrower application domain and makes ease-of-use a primary goal. To this end, we note a couple of subgoals for Musubi that might be seen as deviations from the spirit of Git.
- Wherever possible, provide only one way to do things.
- Encourage each user to keep their own clones (on different devices but under the same user account) as synchronized as possible.

A couple of specific preliminary ways in which Musubi deviates from the core Git model:
- Every change in Musubi is automatically staged, i.e. there is no Musubi equivalent to a manual "git add".
- "Commit + push" is a single operation in Musubi. When disconnected from the Internet (or if the Musubi service goes down), users can still make local edits but cannot create commits.
    - Note that all Musubi-based history can be persisted locally on user's devices, so even if the Musubi service goes down forever, users don't lose their logs and may be able to continue building on top of them using alternative services that can ingest the Musubi data format.
- Musubi does not support multiple *logical* branches within any repository. In other words, every Musubi repository clone only has a "main" branch and associated "\[remote\]/main" branch(es), no user-made "feature" branches.

To allow users to collaborate on and subscribe to different specific playlists, Musubi version-controls each playlist separately, i.e. Musubi treats each playlist as a separate logical repository.

The rest of Musubi's design follows from a couple of key constraints / requirements.

- **Added collaborators do NOT have the ability to modify a shared playlist *through the Spotify API***. In other words, when using the Spotify API, only the "owner"/creator of a playlist can modify it.
    - (Note that added collaborators do have the ability to modify a shared playlist *through the official Spotify app*.)
    - This motivates an overall architecture that closely follows the ["Integration-Manager Workflow (IMW)"](https://git-scm.com/book/en/v2/Distributed-Git-Distributed-Workflows#wfdiag_b), with the "integration manager + blessed repository" roughly mapping to the playlist+repo on the owner's Spotify+Musubi account and the "developer public + private" roughly mapping to the playlistcopy+clone on a collaborator's Spotify+Musubi account.

- **In the Musubi system model, Spotify itself is both the platform to which changes need to be published AND an external actor with direct write privileges".**
    - Musubi is not intended to fully replace usage of the official Spotify clients, since there are multiple features that are not directly supported by the Spotify API and would be too costly/impractical to reproduce. It is expected that most if not all Musubi users will also use an official Spotify client concurrently (e.g. official Spotify client for new music discovery + Musubi for more reliable playlist management and organized collaborative editing + official Spotify client for regular/group listening sessions). This means one of Musubi's requirements is to gracefully and safely handle/propagate changes made by users in Spotify itself - changes that Musubi can't directly observe / react to in real-time (without introducing some inefficient mechanism like polling the Spotify API).
    - An obvious solution-direction that comes to mind is to treat the playlist on Spotify itself as its own clone of the logical repository. This does not directly align with the Git model since the "clone" on Spotify won't be making any explicit "commits" that other clones can organize/synchronize around. However, the spirit of this approach is useful, and Musubi's solution builds on it.

We arrive at the following IMW-based architecture:

The Musubi backend is analogous to the GitHub backend, with key differences being:

- Each Musubi-backend-hosted clone is associated with exactly one Musubi account with direct push access. (OTOH a GitHub-hosted clone may have multiple GitHub accounts with direct push access.) Collaborating through Musubi is all done through [GitHub-like "forking"](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks).
    - Note that a Musubi account can be associated with multiple devices. This is analogous to a GitHub user having multiple local Git clones of the same repo.
    - Note that a Musubi account is also associated with an account on Spotify itself. Interactions between Musubi and Spotify are described in the next bullet point.

- "Pushing" to a Musubi-hosted clone also interacts with Spotify in the following way:
    1. Check if any changes were made on Spotify (i.e. through official Spotify clients) since the last successful push (which marks the last successful sync between Musubi and Spotify).
        - If such changes are detected, the Musubi client must first pull (fetch+merge) in the changes from Spotify to the Musubi local state (creating a new merge commit) before the push can proceed. This is a three-way merge between the current Musubi state, the current Spotify state, and the state at the last successful sync (note this is always an explicit Musubi commit). This makes sure that users don't lose changes they made in Spotify / outside of Musubi. Once the merge is completed locally, the Musubi client restarts the push process (doing the sync check again).
    2. A successful push will update Spotify itself to reflect the current Musubi state. As described above, a push is an atomic action (wrt Spotify) that only succeeds if there is no merge needed when it starts. This ensures that no changes in Spotify are lost without user review.
        - Note that *in theory* there is a race condition: in the context of a single push action, the user might make a change in Spotify in the window between Musubi's successful check (a read from Spotify) and subsequent write to Spotify. *In practice*, this window is so small (10s of milliseconds) that the race condition never occurs under normal human-controlled usage. In other words, it's impossible for users to accidentally trigger it. If a user does manage to trigger it (e.g. by having multiple devices open under the same account and consciously trying to simultaneously make a Spotify edit and a Musubi push on the same playlist), we consider them to be "malicious", but we can safely ignore them since exploiting this race condition only harms their own Musubi-Spotify integration experience.

The following table summarizes how IMW concepts map to Musubi. This table is defined wrt a single logical Musubi repository / Spotify playlist.

| IMW concept | Definition in terms of Git+GitHub | Musubi equivalent |
| --- | --- | --- |
| blessed repository | The GitHub-hosted clone considered to be the "official" project. | The Musubi-hosted clone under the Musubi account of the playlist owner. As described above, on every successful "push" to this Musubi-hosted repository, the original playlist on Spotify is also updated to reflect the Musubi state. |
| integration manager | A local clone with "push" privileges to the blessed repository. Can also review/merge "pull requests" from remote collaborators and push successful merges to the blessed repository. | A Musubi app instance belonging to the playlist owner. |
| developer public | A GitHub-hosted clone considered to be a ["fork"](https://docs.github.com/en/pull-requests/collaborating-with-pull-requests/working-with-forks/about-forks) of the blessed repository. | A Musubi-hosted clone under the Musubi account of a playlist collaborator. Also associated with a complete independent playlist copy on Spotify, itself "owned" by the collaborator. Note that the playlist copy on Spotify plays no IMW-specific role - its sole purpose is to give the collaborator the option of editing Musubi-forked playlists on the official Spotify clients (which may e.g. offer better suggestions for songs to add). |
| developer private | A local clone with "push" privileges to `developer public`. Can send pull requests (wrt successfully-pushed commits on `developer public`) to the integration manager. | A Musubi app instance belonging to a collaborator on the playlist. |

##### Merge conflict resolution in Musubi

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

