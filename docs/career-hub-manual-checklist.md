# Career Hub Manual Verification

- Open the dashboard and confirm the `Career Hub` tile loads [career_hub.tscn](/Users/alexanderdaly/Projects/soccer-rpg/scenes/career/career_hub.tscn).
- Press `Back to Dashboard` and confirm the scene returns to the console dashboard.
- Load a save with an upcoming fixture and confirm the primary action becomes `Play Next Match`.
- Press `Play Next Match` and confirm the game enters the pre-match scene for the next scheduled opponent.
- Load or create a save with at least one pending contract offer and no knockout or national-priority match blocking it.
- Confirm the hub shows the pending offer in the `Offers` section with `Accept` and `Decline` buttons.
- Accept an offer and confirm the hub refreshes immediately, the pending offer disappears, and queued-contract text appears when the move starts next window.
- Decline an offer and confirm the hub refreshes immediately and the pending offer disappears.
- Open the dashboard email panel and desktop email app after resolving an offer and confirm the resolved offer is no longer actionable there.
- Start a new or clean save with no offers, rivals, or relationship data and confirm the empty states render cleanly.
