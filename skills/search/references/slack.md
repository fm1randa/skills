# Slack

Use the Slack MCP. Search public **and** private channels plus Direct Messages — `slack_search_public_and_private` rather than `slack_search_public`, since the decision that answers the question is usually in a private squad channel or a DM.

## Sweeping for an answer

- **Run each term in both languages.** The team mixes Portuguese and English in the same channel: *bug / erro / problema*, *pegar / assumir / take / pick up*, *combinado / decidido / agreed*.
- **Search the IDs and names the spine surfaced**, not only the words in the question. A task ID pasted into a channel is the single highest-yield query available.
- **Read the thread, not the match.** `slack_search_*` returns one message; the answer is usually in the replies. Follow every promising hit with `slack_read_thread`.
- **Search the phrasing people actually use** for commitments — *fica com*, *eu pego*, *pode pegar*, *deixa comigo*, *vou olhar*. These are what turn "there is a bug" into "someone already took it".
- **Resolve people to names.** Use `slack_read_user_profile` so the evidence reads "Sabrina, 27/07" rather than a user ID.

## Reporting

Each finding as: channel, author, date, one-line quote or paraphrase, and permalink. Recency matters — a commitment from yesterday outranks the same commitment from three weeks ago, and the answer should reflect that ordering.
