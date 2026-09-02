using Toybox.Lang;

//! The tier table. Every number that decides how hard a puzzle feels lives
//! here and nowhere else.
//!
//! Difficulty runs on two axes, not one, because clue count alone is a poor
//! predictor: a published "easy" newspaper puzzle with 30 clues and a 30-clue
//! puzzle that needs chained inference look identical on the board.
//!
//!   TARGET_CLUES     how many givens the player starts with
//!   NEEDS_ADVANCED   false: scanning for singles is enough, start to finish
//!                    true:  scanning alone provably stalls at some point
//!
//! The first three tiers hold the technique fixed and take clues away; the
//! last two hold the technique requirement and take clues away again. That
//! gives a ladder where each rung is harder than the one below it for a
//! reason a player can feel.
//!
//! These arrays are mirrored in tools/sudoku_ref.py and compared against it by
//! tools/check_constants.py, and tools/check_generator.py then proves each
//! tier is actually reachable and correctly rated. Change one side without
//! the other and `tools/verify.sh` fails.
module Difficulty {

    const COUNT = 5;

    const BEGINNER = 0;
    const EASY = 1;
    const MEDIUM = 2;
    const HARD = 3;
    const EXPERT = 4;

    const NAMES = ["BEGINNER", "EASY", "MEDIUM", "HARD", "EXPERT"];

    //! How many givens to leave the player. 0 means "leave the puzzle
    //! minimal" - Expert keeps whatever the dig bottomed out at, usually
    //! 23-26, and that sparseness is the whole point of the tier.
    const TARGET_CLUES = [44, 34, 28, 30, 0];

    //! Whether the finished puzzle must defeat naked and hidden singles.
    const NEEDS_ADVANCED = [false, false, false, true, true];

    //! One line of honest advertising per tier, shown under the name in the
    //! difficulty menu.
    const BLURBS = [
        "Scanning only",
        "Scanning only",
        "Scanning, few clues",
        "Needs real deduction",
        "Deduction, fewest clues"
    ];

    function name(tier) {
        return NAMES[tier];
    }

    function blurb(tier) {
        return BLURBS[tier];
    }

    function targetClues(tier) {
        return TARGET_CLUES[tier];
    }

    function needsAdvanced(tier) {
        return NEEDS_ADVANCED[tier];
    }
}
