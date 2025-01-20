use aiken/builtin
use aiken/cbor.{serialise}
use aiken/collection/dict.{to_pairs}
use aiken/primitive/bytearray.{concat}
use cardano/address.{Address, Inline, Script}
use cardano/assets.{Value, ada_policy_id, to_dict}
use cardano/transaction.{InlineDatum, Input, NoDatum, Output, OutputReference}
use intention_types.{
  InputConstraint, Nada, Options, OutputConstraint, SomeOne, SomeTwo,
}
use utils.{at, dataify, quantity_of}

const is_nada = fn(options: Data) { dataify(Nada) == options }

pub fn select_field(field_selection_list: List<Data>, constr: Data) -> Data {
  when field_selection_list is {
    [] -> constr

    [x, ..rest] -> {
      let x = builtin.un_i_data(x)

      constr |> builtin.unconstr_fields |> at(x) |> select_field(rest, _)
    }
  }
}

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

pub fn expect_options_data_tuple_bytearray(
  options: Data,
) -> Options<Data, (ByteArray, ByteArray)> {
  expect options: Options<Data, (ByteArray, ByteArray)> = options
  options
}

pub fn expect_options_data(options: Data) -> Options<Data, Data> {
  expect options: Options<Data, Data> = options
  options
}

pub fn unwrap_option(option: Data) -> Data {
  option |> builtin.unconstr_fields |> builtin.head_list
}

pub fn check_val(vals: List<Data>, value: Value) -> Bool {
  when vals is {
    [] -> True
    [x, ..rest] -> {
      expect (policy, asset, quantity): (ByteArray, ByteArray, Int) = x

      quantity_of(value, policy, asset) == quantity && check_val(rest, value)
    }
  }
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

pub fn handle_inp_constraint(
  inputs: List<Input>,
  con: Data<InputConstraint>,
) -> Data {
  expect InputConstraint { address, value, datum_field, in_ref } = con

  let runnable_val =
    if dataify([]) == value {
      fn(_output) { True }
    } else {
      fn(output: Output) {
        value |> builtin.un_list_data |> check_val(output.value)
      }
    }

  let runnable_address =
    if is_nada(address) {
      runnable_val
    } else {
      when expect_options_data(address) is {
        SomeOne(address) ->
          fn(output: Output) {
            dataify(output.address) == address && runnable_val(output)
          }

        SomeTwo(pay_cred) ->
          fn(output: Output) {
            and {
              dataify(output.address.payment_credential) == pay_cred,
              runnable_val(output),
            }
          }

        Nada -> fail
      }
    }

  let runnable =
    if in_ref == dataify(None) {
      fn(input: Input) { runnable_address(input.output) }
    } else {
      let in_ref = unwrap_option(in_ref)
      fn(input: Input) {
        in_ref == dataify(input.output_reference) && runnable_address(
          input.output,
        )
      }
    }

  apply_constraint_to_inputs(datum_field, inputs, runnable)
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

test handle_inp_constraint_5() {
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

fn apply_constraint_to_inputs(datum_field, inputs: List<Input>, runnable) {
  expect [x, ..rest] = inputs

  if runnable(x) {
    if datum_field == dataify([]) {
      dataify(x.output.datum)
    } else {
      datum_field
        |> builtin.un_list_data
        |> select_field(x.output.datum)
    }
  } else {
    apply_constraint_to_inputs(datum_field, rest, runnable)
  }
}

pub fn handle_out_constraint(
  outputs: List<Output>,
  con: Data<OutputConstraint>,
  temp_val: Data,
) -> Data {
  expect OutputConstraint { address, value, datum, ref } = con

  let runnable_val =
    if is_nada(value) {
      fn(_output) { True }
    } else {
      when expect_options_data_tuple_bytearray(value) is {
        SomeOne(exact_value_check) ->
          fn(output: Output) { dataify(output.value) == exact_value_check }

        SomeTwo((policy, asset_name)) -> {
          let exact_value_check =
            [Pair(policy, [Pair(asset_name, builtin.un_i_data(temp_val))])]
              |> dataify

          if policy == ada_policy_id {
            fn(output: Output) { dataify(output.value) == exact_value_check }
          } else {
            fn(output: Output) {
              when output.value |> to_dict |> to_pairs is {
                [] -> False
                [_, ..rest_value] -> dataify(rest_value) == exact_value_check
              }
            }
          }
        }

        Nada -> fail
      }
    }

  let runnable_datum =
    if is_nada(datum) {
      runnable_val
    } else {
      when expect_options_data_tuple_bytearray(datum) is {
        SomeOne(datum_check) ->
          fn(output: Output) {
            dataify(output.datum) == datum_check && runnable_val(output)
          }

        SomeTwo((pre_bytes, post_bytes)) -> {
          let datum_bytes_check =
            temp_val
              |> serialise
              |> concat(pre_bytes, _)
              |> concat(post_bytes)

          fn(output: Output) { serialise(output.datum) == datum_bytes_check }
        }

        Nada -> fail
      }
    }

  let runnable_ref =
    if ref == dataify(None) {
      runnable_datum
    } else {
      fn(output: Output) {
        ref == dataify(output.reference_script) && runnable_datum(output)
      }
    }

  let runnable =
    if is_nada(address) {
      runnable_ref
    } else {
      when expect_options_data(address) is {
        SomeOne(address) ->
          fn(output: Output) {
            dataify(output.address) == address && runnable_ref(output)
          }

        SomeTwo(pay_cred) ->
          fn(output: Output) {
            and {
              dataify(output.address.payment_credential) == pay_cred,
              runnable_ref(output),
            }
          }

        Nada -> fail
      }
    }

  apply_constraint_to_list(outputs, runnable)
}

fn apply_constraint_to_list(list: List<a>, runnable: fn(a) -> Bool) -> Data {
  expect [x, ..rest] = list

  if runnable(x) {
    dataify(None)
  } else {
    apply_constraint_to_list(rest, runnable)
  }
}
