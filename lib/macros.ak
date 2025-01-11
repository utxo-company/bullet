use aiken/builtin

pub type SkipFuncPieces<a, b> =
  fn(fn(fn(List<a>, Int) -> List<a>, fn(List<a>) -> List<a>, Int) -> b) -> b

// List skip functions and tests
// Skip_count must be greater than or equal to 2
/// This function was found to have the same performance as writing
/// by hand. The other functions below will be improved in following Aiken versions
pub fn list_skipper_macro_pieces(skip_count: Int) -> SkipFuncPieces<a, b> {
  let iterate_func = iterate_index(skip_count - 2)

  let skip_func = skip_list(skip_count)

  fn(a) { a(iterate_func, skip_func, skip_count) }
}

fn skip_list(skip_count: Int) -> fn(List<a>) -> List<a> {
  if skip_count == 0 {
    identity
  } else {
    let func = skip_list(skip_count - 1)

    fn(list) {
      list
        |> builtin.tail_list
        |> func
    }
  }
}

fn iterate_index(skip_count: Int) -> fn(List<a>, Int) -> List<a> {
  if skip_count == 0 {
    fn(list, index) {
      if index == 0 {
        list
      } else {
        builtin.tail_list(list)
      }
    }
  } else {
    let func = iterate_index(skip_count - 1)

    fn(list, index) {
      if index == 0 {
        list
      } else {
        list
          |> builtin.tail_list
          |> func(index - 1)
      }
    }
  }
}

const skipperoo: fn(List<Int>, Int) -> List<Int> = list_skipper_macro_slow(4)

fn skipperoni(list, index) {
  skipperoo(list, index)
}

test skip_list_speed_1_g() {
  and {
    ( skipperoni(x, 8) |> builtin.head_list ) == 11,
    ( skipperoni(x, 8) |> builtin.head_list ) == 11,
    ( skipperoni(x, 8) |> builtin.head_list ) == 11,
  }
}

pub fn list_skipper_macro_slow(skip_count: Int) {
  let func = list_skipper_macro_pieces2(skip_count)

  let iterate_func, skip_func <- func

  fn(list, index) {
    if index >= skip_count {
      list
        |> skip_func
        |> list_skipper_macro_slow(skip_count)(index - skip_count)
    } else {
      iterate_func(list, index)
    }
  }
}

pub fn list_skipper_macro_deprecated(
  skip_count: Int,
) -> fn(List<a>, Int) -> List<a> {
  let iterate_func = iterate_index(skip_count - 2)

  let skip_func = skip_list(skip_count)

  do_list_skipper_macro(iterate_func, skip_func, skip_count)
}

fn do_list_skipper_macro(
  iterate_func,
  skip_func,
  skip_count,
) -> fn(List<a>, Int) -> List<a> {
  fn(list, index) {
    if index >= skip_count {
      list
        |> skip_func
        |> do_list_skipper_macro(iterate_func, skip_func, skip_count)(
            index - skip_count,
          )
    } else {
      iterate_func(list, index)
    }
  }
}

pub fn list_skipper_macro_pieces2(
  skip_count: Int,
) -> fn(fn(fn(List<a>, Int) -> List<a>, fn(List<a>) -> List<a>) -> b) -> b {
  let iterate_func = iterate_index(skip_count - 2)

  let skip_func = skip_list(skip_count)

  fn(a) { a(iterate_func, skip_func) }
}

pub fn skip_list_mega_fast(l: List<a>, i: Int) -> List<a> {
  if i < 4 {
    skip_list_mega(l, i)
  } else {
    l
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> skip_list_mega_fast(i - 4)
  }
}

fn skip_list_mega(l: List<a>, i: Int) -> List<a> {
  if i == 0 {
    l
  } else {
    let i = i - 1
    let l = builtin.tail_list(l)

    if i == 0 {
      l
    } else {
      let i = i - 1
      let l = builtin.tail_list(l)

      if i == 0 {
        l
      } else {
        builtin.tail_list(l)
      }
    }
  }
}

fn skip_list_mega_2(i: Int) -> fn(List<a>, Int) -> List<a> {
  if i == 0 {
    fn(list, index) {
      if index == 0 {
        list
      } else {
        builtin.tail_list(list)
      }
    }
  } else {
    let func = skip_list_mega_2(i - 1)

    fn(list, index) {
      if index == 0 {
        list
      } else {
        builtin.tail_list(list) |> func(index - 1)
      }
    }
  }
}

const x = [1, 2, 3, 5, 7, 8, 0, 10, 11, 212, 23, 25]

test skip_list_speed_a() {
  and {
    ( skip_list_mega(x, 2) |> builtin.head_list ) == 3,
    ( skip_list_mega(x, 2) |> builtin.head_list ) == 3,
    ( skip_list_mega(x, 2) |> builtin.head_list ) == 3,
  }
}

const skip: fn(List<Int>, Int) -> List<Int> = skip_list_mega_2(2)

test skip_list_speed_b() {
  let skippee = skip
  and {
    ( skippee(x, 2) |> builtin.head_list ) == 3,
    ( skippee(x, 2) |> builtin.head_list ) == 3,
    ( skippee(x, 2) |> builtin.head_list ) == 3,
  }
}

fn skippee2(l, i) {
  skip(l, i)
}

test skip_list_speed_c() {
  and {
    ( skippee2(x, 2) |> builtin.head_list ) == 3,
    ( skippee2(x, 2) |> builtin.head_list ) == 3,
    ( skippee2(x, 2) |> builtin.head_list ) == 3,
  }
}

test skip_list_speed_3_s() {
  ( skip_list_mega_fast(x, 0) |> builtin.head_list ) == 1
}

test skip_list_speed_4_s() {
  ( skip_list_mega_fast(x, 1) |> builtin.head_list ) == 2
}

test skip_list_speed_5_s() {
  ( skip_list_mega_fast(x, 2) |> builtin.head_list ) == 3
}

test skip_list_speed_6_s() {
  ( skip_list_mega_fast(x, 3) |> builtin.head_list ) == 5
}

test skip_list_speed_7_s() {
  ( skip_list_mega_fast(x, 4) |> builtin.head_list ) == 7
}

test skip_list_speed_8_s() {
  ( skip_list_mega_fast(x, 5) |> builtin.head_list ) == 8
}

test skip_list_speed_9_s() {
  ( skip_list_mega_fast(x, 6) |> builtin.head_list ) == 0
}

test skip_list_speed_1_s() {
  and {
    ( skip_list_mega_fast(x, 8) |> builtin.head_list ) == 11,
    ( skip_list_mega_fast(x, 8) |> builtin.head_list ) == 11,
    ( skip_list_mega_fast(x, 8) |> builtin.head_list ) == 11,
  }
}

const jing: fn(
    fn(fn(List<Int>, Int) -> List<Int>, fn(List<Int>) -> List<Int>, Int) ->
      List<Int>,
  ) ->
    List<Int> =
  list_skipper_macro_pieces(4)

fn thing(list, index) {
  let iterate_func, skip_func, skip_count <- jing

  if index >= skip_count {
    list |> skip_func |> thing(index - skip_count)
  } else {
    iterate_func(list, index)
  }
}

test skip_list_speed_1_f() {
  and {
    ( thing(x, 8) |> builtin.head_list ) == 11,
    ( thing(x, 8) |> builtin.head_list ) == 11,
    ( thing(x, 8) |> builtin.head_list ) == 11,
  }
}

test skip_list_speed_11_s() {
  ( skip_list_mega_fast(x, 9) |> builtin.head_list ) == 212
}

test skip_list_speed_2_s() {
  ( skip_list_mega_fast(x, 11) |> builtin.head_list ) == 25
}

fn interesting(i: Int) -> fn(List<a>) -> List<a> {
  if i == 0 {
    identity
  } else {
    let func = interesting(i - 1)

    fn(list) { func(list) |> builtin.tail_list }
  }
}

const something: fn(List<ByteArray>) -> List<ByteArray> = interesting(8)

test other() {
  let x = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]

  let y = something(x)

  let g = something(x) |> builtin.head_list

  y == ["i"] && g == "i"
}

test other_2() {
  let x = ["a", "b", "c", "d", "e", "f", "g", "h", "i"]

  let y =
    x
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list

  let g =
    x
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.tail_list
      |> builtin.head_list

  y == ["i"] && g == "i"
}
