//SPDX-FileCopyrightText: 2024 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

use crate::{ShellCore,Feeder};
use super::CalcElement;

fn op_order(operator: &str) -> u8 {
    let op: &str = &operator.clone();

    match op {
        "**" => 5,
        "*" | "/" | "%"            => 6, 
        "+" | "-"                  => 7, 
        "<<" | ">>"                => 8, 
        "<=" | ">=" | ">" | "<"    => 9, 
        "(" | ")"                  => 20, 
        _ => 255, 
    }
}

fn to_op_str(calc_elem: Option<&CalcElement>) -> Option<&str> {
    match calc_elem {
        Some(CalcElement::Op(s)) => Some(&s),
        _ => None,
    }
}

fn rev_polish(elements: &Vec<CalcElement>) -> Vec<CalcElement> {
    let mut ans = vec![];
    let mut stack = vec![];

    for e in elements {
        match e {
            CalcElement::Num(n) => ans.push(CalcElement::Num(*n)),
            CalcElement::Op(s) => {
                loop {
                    match to_op_str(stack.last()) {
                        None | Some("(") => {
                            stack.push(CalcElement::Op(s.clone()));
                            break;
                        },
                        Some(")") => {
                            stack.pop();
                            loop {
                                match to_op_str(stack.last()) {
                                    None => {},
                                    Some("(") => {
                                        stack.pop();
                                        break;
                                    },
                                    Some(e) => ans.push(CalcElement::Op(e.to_string())),
                                }
                            }
                        },
                        Some(top_str) => {
                            if op_order(top_str) > op_order(s) {
                                stack.push(CalcElement::Op(s.clone()));
                                break;
                            }else{
                                ans.push(stack.pop().unwrap());
                            }
                        },
                    }
                }
            },
            _ => {},
        }
    }

    while stack.len() > 0 {
        ans.push(stack.pop().unwrap());
    }

    ans
}

fn operation_plus(stack: &mut Vec<CalcElement>) {
    if stack.len() < 2 {
        panic!("SUSH INTERNAL ERROR: wrong operation");
    }

    let right = match stack.pop() {
        Some(CalcElement::Num(s)) => s,
        _ => panic!("SUSH INTERNAL ERROR: wrong operation"),
    };

    let left = match stack.pop() {
        Some(CalcElement::Num(s)) => s,
        _ => panic!("SUSH INTERNAL ERROR: wrong operation"),
    };

    stack.push( CalcElement::Num(right + left) );
}

fn operation(op: &str, stack: &mut Vec<CalcElement>) {
    match op {
        "+" => operation_plus(stack),
        _ => {},
    }
}


pub fn calculate(elements: &Vec<CalcElement>) -> Option<CalcElement> {
    let rev_pol = rev_polish(&elements);
    let mut stack = vec![];

    for e in rev_pol {
        match e {
            CalcElement::Num(s) => stack.push(e),
            CalcElement::Op(op) => operation(&op, &mut stack),
            _ => return None,
        }
    }

    if stack.len() != 1 {
        panic!("SUSH INTERNAL ERROR: wrong operation");
    }

    stack.pop()
}
