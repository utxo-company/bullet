use aiken/builtin
use cardano/address.{Address, Inline, Script}
use cardano/assets.{ada_policy_id}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use constraint_utils.{
  check_val, handle_inp_constraint, handle_out_constraint, select_field,
}
use intention_types.{InputConstraint, Nada, OutputConstraint, SomeOne, SomeTwo}
use utils.{dataify}

const test_thing = {
    let thing_1 =
      builtin.constr_data(2, [dataify("a"), dataify(1), dataify([2])])

    let thing_2 =
      builtin.constr_data(1, [dataify("b"), thing_1, dataify(["ab"])])

    builtin.constr_data(5, [thing_2, dataify(1), thing_1])
  }

const test_list = [dataify("a"), dataify(1), dataify([2])]

test select_field_1() {
  select_field([dataify(0), dataify(1), dataify(2)], test_thing) == dataify([2])
}

test select_field_empty() {
  select_field([], test_thing) == test_thing
}

test select_field_3() {
  select_field([dataify(1)], test_thing) == dataify(1)
}

test select_field_4() {
  select_field([dataify(2), dataify(0)], test_thing) == dataify("a")
}

test select_field_out_of_range() fail {
  select_field([dataify(2), dataify(3)], test_thing) == dataify("a")
}

test select_field_cant_do_list() fail {
  select_field([dataify(1)], test_list) == dataify(1)
}

test check_val_1() {
  let value = assets.from_asset("ab", "cd", 50) |> assets.add("", "", 1000000)
  check_val([dataify(("ab", "cd", 50))], value)
}

test check_val_2() {
  let value = assets.from_asset("ab", "cd", 50) |> assets.add("", "", 1000000)
  check_val([dataify(("", "", 1000000))], value)
}

test check_val_3() {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)
  check_val(
    [
      dataify(("", "", 1000000)),
      dataify(("ab", "cd", 50)),
      dataify(("de", "fg", 1)),
    ],
    value,
  )
}

test check_val_4() fail {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)
  check_val([dataify(("", "", 2000000))], value)
}

test handle_inp_constraint_0() {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)

  let con =
    InputConstraint { address: Nada, value: [], datum_field: [], in_ref: None }

  let input =
    Input(
      OutputReference("abcd", 1),
      Output(Address(Script("thing"), None), value, NoDatum, None),
    )

  handle_inp_constraint([input], con) == dataify(NoDatum)
}

test handle_inp_constraint_1() {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)

  let con =
    InputConstraint {
      address: SomeOne(Address(Script("thing"), None)),
      value: [("ab", "cd", 50)],
      datum_field: [],
      in_ref: None,
    }

  let input =
    Input(
      OutputReference("abcd", 1),
      Output(Address(Script("thing"), None), value, NoDatum, None),
    )

  handle_inp_constraint([input], con) == dataify(NoDatum)
}

test handle_inp_constraint_2() fail {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)

  let con =
    InputConstraint {
      address: SomeOne(Address(Script("thing"), None)),
      value: [("ab", "cd", 50)],
      datum_field: [],
      in_ref: None,
    }

  let input =
    Input(
      OutputReference("abcd", 1),
      Output(
        Address(Script("thing"), Some(Inline(Script("other")))),
        value,
        NoDatum,
        None,
      ),
    )

  handle_inp_constraint([input], con) == dataify(NoDatum)
}

test handle_inp_constraint_3() fail {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)

  let con =
    InputConstraint {
      address: SomeOne(Address(Script("thing"), None)),
      value: [("ab", "cd", 50)],
      datum_field: [],
      in_ref: None,
    }

  let input =
    Input(
      OutputReference("abcd", 1),
      Output(Address(Script("thing"), None), value, NoDatum, None),
    )

  handle_inp_constraint([input], con) == dataify(InlineDatum("1"))
}

test handle_inp_constraint_4() {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)

  let con =
    InputConstraint {
      address: SomeOne(Address(Script("thing"), None)),
      value: [("ab", "cd", 50)],
      datum_field: [],
      in_ref: Some(OutputReference("abcd", 1)),
    }

  let input =
    Input(
      OutputReference("abcd", 1),
      Output(Address(Script("thing"), None), value, NoDatum, None),
    )

  handle_inp_constraint([input], con) == dataify(NoDatum)
}

test handle_inp_constraint_5() fail {
  let value =
    assets.from_asset("ab", "cd", 50)
      |> assets.add("", "", 1000000)
      |> assets.add("de", "fg", 1)

  let con =
    InputConstraint {
      address: SomeOne(Address(Script("thing"), None)),
      value: [("ab", "cd", 50), ("de", "fg", 2)],
      datum_field: [],
      in_ref: Some(OutputReference("abcd", 1)),
    }

  let input =
    Input(
      OutputReference("abcd", 1),
      Output(Address(Script("thing"), None), value, NoDatum, None),
    )

  handle_inp_constraint([input], con) == dataify(NoDatum)
}

test handle_out_constraint_basic() {
  let value = assets.from_lovelace(1000000)

  let output =
    Output(Address(Script("test_script"), None), value, NoDatum, None)

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_value_match() {
  let value =
    assets.from_lovelace(1000000)
      |> assets.add("policy1", "asset1", 50)

  let output =
    Output(Address(Script("test_script"), None), value, NoDatum, None)

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(SomeTwo(("policy1", "asset1"))),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(50)) == dataify(None)
}

test handle_out_constraint_address_match() {
  let addr = Address(Script("test_script"), None)
  let output = Output(addr, assets.from_lovelace(1000000), NoDatum, None)

  let constraint =
    OutputConstraint {
      address: dataify(SomeOne(addr)),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_address_mismatch() fail {
  let addr1 = Address(Script("script1"), None)
  let addr2 = Address(Script("script2"), None)
  let output = Output(addr1, assets.from_lovelace(1000000), NoDatum, None)

  let constraint =
    OutputConstraint {
      address: dataify(SomeOne(addr2)),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_datum_exact_match() {
  let datum = InlineDatum("test_datum")
  let output =
    Output(
      Address(Script("test_script"), None),
      assets.from_lovelace(1000000),
      datum,
      None,
    )

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(Nada),
      datum: dataify(SomeOne(datum)),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_datum_bytes() {
  let pre_bytes = #"d87b9fd8799f"
  let post_bytes = #"ffff"
  let test_val = dataify("test_value")

  let output =
    Output(
      Address(Script("test_script"), None),
      assets.from_lovelace(1000000),
      InlineDatum(Some(test_val)),
      None,
    )

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(Nada),
      datum: dataify(SomeTwo((pre_bytes, post_bytes))),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, test_val) == dataify(None)
}

test handle_out_constraint_multiple_outputs() {
  let addr1 = Address(Script("script1"), None)
  let addr2 = Address(Script("script2"), None)

  let value1 = assets.from_lovelace(1000000)
  let value2 =
    assets.from_lovelace(2000000)
      |> assets.add("policy1", "asset1", 50)

  let outputs =
    [Output(addr1, value1, NoDatum, None), Output(addr2, value2, NoDatum, None)]

  let constraint =
    OutputConstraint {
      address: dataify(SomeOne(addr2)),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint(outputs, constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_payment_credential() {
  let payment_cred = Script("test_payment")
  let addr = Address(payment_cred, None)

  let output = Output(addr, assets.from_lovelace(1000000), NoDatum, None)

  let constraint =
    OutputConstraint {
      address: dataify(SomeTwo(payment_cred)),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_reference_script() {
  let script_hash = #"deadbeef"
  let output =
    Output(
      Address(Script("test_script"), None),
      assets.from_lovelace(1000000),
      NoDatum,
      Some(script_hash),
    )

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(Some(script_hash)),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_combined() {
  let script_hash = #"deadbeef"
  let payment_cred = Script("test_payment")
  let addr = Address(payment_cred, None)
  let datum = InlineDatum("test_datum")

  let value =
    assets.from_lovelace(1000000)
      |> assets.add("policy1", "asset1", 50)

  let output = Output(addr, value, datum, Some(script_hash))

  let constraint =
    OutputConstraint {
      address: dataify(SomeTwo(payment_cred)),
      value: dataify(SomeTwo(("policy1", "asset1"))),
      datum: dataify(SomeOne(datum)),
      ref: dataify(Some(script_hash)),
    }

  handle_out_constraint([output], constraint, dataify(50)) == dataify(None)
}

test handle_out_constraint_ada_value() {
  let output =
    Output(
      Address(Script("test_script"), None),
      assets.from_lovelace(1000000),
      NoDatum,
      None,
    )

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(SomeTwo((ada_policy_id, #""))),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(1000000)) == dataify(None)
}

test handle_out_constraint_wrong_reference_script() fail {
  let output =
    Output(
      Address(Script("test_script"), None),
      assets.from_lovelace(1000000),
      NoDatum,
      Some(#"deadbeef"),
    )

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(Nada),
      datum: dataify(Nada),
      ref: dataify(Some(#"beefdead")),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_wrong_datum() fail {
  let output =
    Output(
      Address(Script("test_script"), None),
      assets.from_lovelace(1000000),
      InlineDatum("actual_datum"),
      None,
    )

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(Nada),
      datum: dataify(SomeOne(InlineDatum("expected_datum"))),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(0)) == dataify(None)
}

test handle_out_constraint_wrong_value() fail {
  let value =
    assets.from_lovelace(1000000)
      |> assets.add("policy1", "asset1", 50)

  let output =
    Output(Address(Script("test_script"), None), value, NoDatum, None)

  let constraint =
    OutputConstraint {
      address: dataify(Nada),
      value: dataify(SomeTwo(("policy1", "asset1"))),
      datum: dataify(Nada),
      ref: dataify(None),
    }

  handle_out_constraint([output], constraint, dataify(100)) == dataify(None)
}
