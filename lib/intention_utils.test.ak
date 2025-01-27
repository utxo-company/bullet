use intention_utils.{fast_combine_output_value}
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

test fast_combine_output_value_multiple() {
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
