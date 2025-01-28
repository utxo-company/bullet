use intention_utils.{fast_combine_natural_values, fast_combine_output_value}
use utils.{dataify}

test fast_combine_output_value_empty() {
  // Test combining with empty right list returns original left list unchanged
  let left =
    [Pair(dataify(#"1234"), dataify([Pair(dataify(#"5678"), dataify(100))]))]
  let right = []

  fast_combine_output_value(left, right) == left
}

test fast_combine_output_value_empty_left() {
  // Test combining with empty right list returns original left list unchanged
  let left = []

  let right =
    [Pair(dataify(#"1234"), dataify([Pair(dataify(#"5678"), dataify(100))]))]

  fast_combine_output_value(left, right) == right
}

test fast_combine_output_value_disjoint() {
  // Test combining two lists with different policy IDs preserves order
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]

  let right =
    [Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]

  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
    ]

  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_same_policy() {
  // Test combining values under same policy ID adds the amounts
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]

  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(200))]))]

  let expected =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(300))]))]

  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_multiple_same_policy() fail {
  // Test combining multiple policies and assets
  let left =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
          ],
        ),
      ),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]

  let right =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(400)),
            Pair(dataify(#"bbbb"), dataify(500)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(600)),
            Pair(dataify(#"dddd"), dataify(600)),
          ],
        ),
      ),
    ]

  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(500)),
            Pair(dataify(#"bbbb"), dataify(700)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(900)),
            Pair(dataify(#"dddd"), dataify(600)),
          ],
        ),
      ),
    ]

  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_one_same_policy() {
  // Test combining multiple policies and assets
  let left =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
          ],
        ),
      ),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]

  let right =
    [
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(600)),
            Pair(dataify(#"dddd"), dataify(600)),
          ],
        ),
      ),
      Pair(
        dataify(#"3333"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(600)),
            Pair(dataify(#"dddd"), dataify(600)),
          ],
        ),
      ),
    ]

  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(900)),
            Pair(dataify(#"dddd"), dataify(600)),
          ],
        ),
      ),
      Pair(
        dataify(#"3333"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(600)),
            Pair(dataify(#"dddd"), dataify(600)),
          ],
        ),
      ),
    ]

  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_insert_middle_policy() fail {
  // Tests inserting a policy between two existing policies in the left list
  let left =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  let right =
    [Pair(dataify(#"3333"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  let expected =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_right_policies_before_left() fail {
  // Tests when right list contains policies that should be ordered before all left policies
  let left =
    [
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  let right =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_asset_insert_middle() fail {
  // Tests inserting an asset between two existing assets within the same policy
  let left =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
    ]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_asset_before_left() fail {
  // Tests adding an asset with a key before existing assets in the same policy
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"cccc"), dataify(300))]))]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_complex_merge() fail {
  // Tests complex merging scenario with multiple policies and asset combinations
  let left =
    [
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"bbbb"), dataify(200)),
            Pair(dataify(#"dddd"), dataify(400)),
          ],
        ),
      ),
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"eeee"), dataify(500)),
            Pair(dataify(#"ffff"), dataify(700)),
          ],
        ),
      ),
    ]
  let right =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(150)),
            Pair(dataify(#"bbbb"), dataify(250)),
          ],
        ),
      ),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"dddd"), dataify(350))])),
    ]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(150)),
            Pair(dataify(#"bbbb"), dataify(450)),
            Pair(dataify(#"dddd"), dataify(400)),
          ],
        ),
      ),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"dddd"), dataify(350))])),
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"eeee"), dataify(500)),
            Pair(dataify(#"ffff"), dataify(700)),
          ],
        ),
      ),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_valid_policy_continuation() {
  // Right starts with same policy as left's last (4444) with asset continuation
  let left =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"cccc"), dataify(200))])),
    ]
  let right =
    [
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(300)),
            // Matches left's last asset
            Pair(dataify(#"dddd"), dataify(400)),
          ],
        ),
      ),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  let expected =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"cccc"), dataify(500)),
            // 200 + 300
            Pair(dataify(#"dddd"), dataify(400)),
          ],
        ),
      ),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_asset_exact_match() {
  // Same policy with right's first asset exactly matching left's last asset
  let left =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
          ],
        ),
      ),
    ]
  let right =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"bbbb"), dataify(300)),
            // Exact match of left's last
            Pair(dataify(#"cccc"), dataify(400)),
          ],
        ),
      ),
    ]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(500)),
            // 200 + 300
            Pair(dataify(#"cccc"), dataify(400)),
          ],
        ),
      ),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_right_higher_policy() {
  // Right's first policy is higher than left's last policy
  let left =
    [Pair(dataify(#"2222"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  let right =
    [Pair(dataify(#"3333"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  let expected =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_multiple_right_policies() {
  // Multiple right policies all ≥ left's last policy
  let left =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  let right =
    [
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(200))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(500))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_output_value_same_policy_asset_growth() {
  // Same policy with right adding new higher assets after left's last
  let left =
    [
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(200)),
          ],
        ),
      ),
    ]
  let right =
    [
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"eeee"), dataify(300)),
            // Higher than left's last asset
            Pair(dataify(#"ffff"), dataify(400)),
          ],
        ),
      ),
    ]
  let expected =
    [
      Pair(
        dataify(#"4444"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(200)),
            Pair(dataify(#"eeee"), dataify(300)),
            Pair(dataify(#"ffff"), dataify(400)),
          ],
        ),
      ),
    ]
  fast_combine_output_value(left, right) == expected
}

test fast_combine_natural_values_empty_right() {
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  let right = []
  fast_combine_natural_values(left, right) == left
}

test fast_combine_natural_values_empty_left() {
  let left = []
  let right =
    [Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  fast_combine_natural_values(left, right) == right
}

test fast_combine_natural_values_interleaved_policies() {
  // Right policy should be inserted before left policy
  let left =
    [Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_same_policy_merge() fail {
  // Should sum assets within same policy but values must respect dict ordering
  let left =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  let right =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(400))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(500))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_complex_insertion() fail {
  // Mixed policy insertions and asset merges
  let left =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  let right =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(500))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(700))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_asset_insertion() {
  // New asset inserted before existing in same policy
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"cccc"), dataify(300))]))]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            // Inserted before
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_multi_asset_merge() {
  // Multiple asset merges in same policy
  let left =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
    ]
  let right =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"bbbb"), dataify(200)),
            Pair(dataify(#"cccc"), dataify(400)),
          ],
        ),
      ),
    ]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
            Pair(dataify(#"cccc"), dataify(700)),
          ],
        ),
      ),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_unordered_policies() {
  // Right policies should be sorted into correct positions
  let left =
    [
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  let right =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  let expected =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_complex_insertion_valid() {
  // Right list maintains policy order during insertion
  let left =
    [
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  let right =
    [
      // Right list must be ordered by policy ID
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(500))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(700))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_same_policy_merge_valid() {
  // Right list maintains proper policy order
  let left =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  let right =
    [
      // Right must be ordered by policy ID
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(400))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(500))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"bbbb"), dataify(200))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_mixed_order_insertion() {
  // Demonstrates right list can have lower policies than left
  let left =
    [
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  let right =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      // Lower than left
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
    ]
  let expected =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"3333"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
      Pair(dataify(#"4444"), dataify([Pair(dataify(#"dddd"), dataify(400))])),
      Pair(dataify(#"5555"), dataify([Pair(dataify(#"eeee"), dataify(500))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_same_asset_merge() {
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(200))]))]
  let expected =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(300))]))]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_new_asset_insertion() {
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"cccc"), dataify(300))]))]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  // Lower asset ID
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_asset_order_preservation() {
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  let right =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))]))]
  // Lower asset
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
          ],
        ),
      ),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_cross_policy_assets() {
  let left =
    [Pair(dataify(#"1111"), dataify([Pair(dataify(#"bbbb"), dataify(200))]))]
  let right =
    [
      Pair(dataify(#"1111"), dataify([Pair(dataify(#"aaaa"), dataify(100))])),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"bbbb"), dataify(200)),
          ],
        ),
      ),
      Pair(dataify(#"2222"), dataify([Pair(dataify(#"cccc"), dataify(300))])),
    ]
  fast_combine_natural_values(left, right) == expected
}

test fast_combine_natural_values_complex_asset_merge() {
  let left =
    [
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"bbbb"), dataify(200)),
            Pair(dataify(#"dddd"), dataify(400)),
          ],
        ),
      ),
    ]
  let right =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(150)),
            // New asset
            Pair(dataify(#"bbbb"), dataify(500)),
          ],
        ),
      ),
    ]
  // Existing asset
  let expected =
    [
      Pair(
        dataify(#"1111"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(100)),
            Pair(dataify(#"cccc"), dataify(300)),
          ],
        ),
      ),
      Pair(
        dataify(#"2222"),
        dataify(
          [
            Pair(dataify(#"aaaa"), dataify(150)),
            Pair(dataify(#"bbbb"), dataify(700)),
            Pair(dataify(#"dddd"), dataify(400)),
          ],
        ),
      ),
    ]
  fast_combine_natural_values(left, right) == expected
}
