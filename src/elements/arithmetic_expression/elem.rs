//SPDX-FileCopyrightText: 2024 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

use super::ArithmeticExpr;
use super::Word;

#[derive(Debug, Clone)]
pub enum Elem {
    UnaryOp(String),
    BinaryOp(String),
    Integer(i64),
    Float(f64),
    Ternary(Box<Option<ArithmeticExpr>>, Box<Option<ArithmeticExpr>>),
    Word(Word, i64), // Word + post increment or decrement
    LeftParen,
    RightParen,
    Increment(i64), //pre increment
//    OutputFormat(String, bool), // ex.: [#8] -> Base("8", false), [##16] -> Base("16", true) 
}

pub fn op_order(op: &Elem) -> u8 {
    match op {
        Elem::Increment(_) => 14,
        Elem::UnaryOp(s) => {
            match s.as_str() {
                "-" | "+" => 14,
                _         => 13,
            }
        },
        Elem::BinaryOp(s) => {
            match s.as_str() {
                "**"            => 12, 
                "*" | "/" | "%" => 11, 
                "+" | "-"       => 10, 
                "<<" | ">>"     => 9, 
                "<=" | ">=" | ">" | "<" => 8, 
                "==" | "!="     => 7, 
                "&"             => 6, 
                "^"             => 5, 
                "|"             => 4, 
                _               => 2,
            }
        },
        Elem::Ternary(_, _) => 1,
        _ => 0, 
    }
}

pub fn to_string(op: &Elem) -> String {
    match op {
        Elem::Integer(n) => n.to_string(),
        Elem::Float(f) => f.to_string(),
        Elem::Word(w, inc) => {
            match inc {
                1  => w.text.clone() + "++",
                -1 => w.text.clone() + "--",
                _  => w.text.clone(),
            }
        },
        Elem::UnaryOp(s) => s.clone(),
        Elem::BinaryOp(s) => s.clone(),
        Elem::LeftParen => "(".to_string(),
        Elem::RightParen => ")".to_string(),
        Elem::Increment(1) => "++".to_string(),
        Elem::Increment(-1) => "--".to_string(),
        _ => "".to_string(),
    }
}
