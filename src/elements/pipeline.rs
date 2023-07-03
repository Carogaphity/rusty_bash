//SPDX-FileCopyrightText: 2022 Ryuichi Ueda ryuichiueda@gmail.com
//SPDX-License-Identifier: BSD-3-Clause

use crate::{Feeder, ShellCore, PipeRecipe};
use nix::unistd;
use super::command;
use super::command::Command;

#[derive(Debug)]
pub struct Pipeline {
    pub commands: Vec<Box<dyn Command>>,
    pub pipes: Vec<String>,
    pub text: String,
}

impl Pipeline {
    pub fn exec(&mut self, core: &mut ShellCore) {
        let mut p = PipeRecipe{recv: -1, send: -1, prev: -1};
        for (i, _) in self.pipes.iter().enumerate() {
            (p.recv, p.send) = unistd::pipe().expect("Cannot open pipe");
            self.commands[i].exec(core, &mut p);
            p.prev = p.recv;
        }

        (p.recv, p.send) = (-1, -1);
        self.commands[self.pipes.len()].exec(core, &mut p);
    }

    pub fn new() -> Pipeline {
        Pipeline {
            text: String::new(),
            commands: vec![],
            pipes: vec![]
        }
    }

    fn eat_command(feeder: &mut Feeder, ans: &mut Pipeline, core: &mut ShellCore) -> bool {
        if let Some(command) = command::parse(feeder, core){
            ans.text += &command.get_text();
            ans.commands.push(command);

            let blank_len = feeder.scanner_blank(core);
            ans.text += &feeder.consume(blank_len);
            true
        }else{
            false
        }
    }

    fn eat_pipe(feeder: &mut Feeder, ans: &mut Pipeline, core: &mut ShellCore) -> bool {
        let len = feeder.scanner_pipe(core);
        if len > 0 {
            let p = feeder.consume(len);
            ans.pipes.push(p.clone());
            ans.text += &p;

            let blank_len = feeder.scanner_blank(core);
            ans.text += &feeder.consume(blank_len);
            true
        }else{
            false
        }
    }

    fn eat_blank_and_comment(feeder: &mut Feeder, ans: &mut Pipeline, core: &mut ShellCore) {
        loop {
            let blank_len = feeder.scanner_multiline_blank(core);
            ans.text += &feeder.consume(blank_len);             //空白、空行を削除
            let comment_len = feeder.scanner_comment();
            ans.text += &feeder.consume(comment_len);             //コメントを削除
            if blank_len + comment_len == 0 { //空白、空行、コメントがなければ出る
                break;
            }
        }
    }

    pub fn parse(feeder: &mut Feeder, core: &mut ShellCore) -> Option<Pipeline> {
        let mut ans = Pipeline::new();

        if ! Self::eat_command(feeder, &mut ans, core){      //最初のコマンド
            return None;
        }

        while Self::eat_pipe(feeder, &mut ans, core){
            loop {                                     //パイプの後ろでの処理
                Self::eat_blank_and_comment(feeder, &mut ans, core);
                if Self::eat_command(feeder, &mut ans, core){
                    break; //コマンドがあれば73行目のloopを抜けてパイプを探す
                }
                if ! feeder.feed_additional_line(core) { //追加の行の読み込み
                    return None;
                }
            }
        }

        Some(ans)
    }
}
