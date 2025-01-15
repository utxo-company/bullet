use aiken/builtin
use aiken/cbor.{serialise}
use aiken/collection/dict.{to_pairs}
use aiken/primitive/bytearray.{concat}
use cardano/assets.{Value, ada_policy_id, to_dict}
use cardano/transaction.{Input, Output}
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

fn apply_constraint_to_inputs(datum_field, inputs: List<Input>, runnable) {
  expect [x, ..rest] = inputs

  if runnable(x) {
    if datum_field == dataify([]) {
      dataify(None)
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
