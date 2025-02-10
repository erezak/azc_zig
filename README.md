# azc - LLM Chat from the command-line
A partial clone of [Sagi's azc](https://github.com/sagism/azc/) written in zig.
This README has been adapted from the original azc README.

A command-line tool for interacting with LLMs.

<!-- ![AZC screenshot](assets/sample.gif) -->

# Why should you use this?

- If you're a command-line junkie, you don't need to switch to another tool to chat with your LLM
- One tool, multiple LLMs (OpenAI, Anthropic, Ollama, Gemini...) - Why settle for one when you can have them all?
- Pay-as-you-go pricing for LLM providers (Cheaper in many cases)

# Features

- Multi-provider support
  - Ollama
  - (TBD) OpenAI
  - (TBD) Anthropic
  - (TBD) Gemini
  - (TBD) Grok
- Streaming responses (see response as it is being generated)

# Feature Parity with AZC, TBD
- Persistent command-line history (use up and down arrows to navigate)
- Chat history & reset (full discussion, start new chat)
- Switch provider and model (compare models and providers)
- Markdown output (nicely formatted headings, lists, tables, etc.)
- Command-line parameters (first prompt)

# Installation

    compile with zig toolchain and run

# Running

```
    % ./azc
Welcome to azc in Zig! Type 'h' or '?' for help.

azc> h
 Just type your message and press enter to start a chat.
 Available commands:

 | Command | Description                 |
 |---------|-----------------------------|
 | l       | List models                 |
 | r       | Refresh models              |
 | n       | New chat                    |
 | h       | Help (this screen)          |
 | m       | Change model                |
 | p       | Change provider             |
 | q       | Quit                        |

azc> l
Available models:
- phi4:14b

azc> How many 'r's in 'Strawberrry'?
Processing message...
The word "Strawberry" contains three 'r' letters.
azc> That's wrong
Processing message...
There are three 'r's in "Strawberry."
azc> But I didn't write 'Strawberry'
Processing message...
There are two 'r's in "Strawberrry" as you've written it. Despite the typo, your version contains those letters!
azc> There are more
Processing message...
In "Strawberrry," there are four 'r's. The spelling differs from the standard "Strawberry."
azc> Thank you!
Processing message...
In the word "Strawberry," there are two 'r's. If you're thinking of a different context or spelling, please clarify!
azc> q
:wave: Goodbye!
```

## Commands

| Command       | Description                                                                    |
| ------------- | ------------------------------------------------------------------------------ |
| `q` or `exit` | Exit the program                                                               |
| `h` or `?`    | Show help                                                                      |
| `l`           | List models                                                                    |
| `n`           | Start new chat                                                                 |
| `p`           | Change provider. `p ` - (`p` followed by a space) trigger auto-completion menu |
| `m`           | Change model                                                                   |
| `ctrl-n`      | New line                                                                       |


# Setup

You will need to configure at least one LLM API.

You should create a `.env` file which contains your API Key/s.
The `.env` file should be located in home directory, either directly under `$HOME` or under `$HOME/.config/`, the latter taking precedence.
See `.env.sample` for a sample `.env` file, with the expected environment variables' names. Remove those that are not relevant to you.

Here are the links to the API sign-up pages (or download in case of Ollama):

- [OpenAI](https://platform.openai.com/signup)
- [Anthropic](https://console.anthropic.com/)
- [Ollama](https://ollama.com/)
- [Gemini](https://ai.google.dev/gemini-api/docs)
- [Grok](https://docs.x.ai/api/integrations)

# Limitations

- Streaming updates are limited to screen height (after that it displays ellipsis and will update the display only when the response is complete)
- Very limited support for RTL languages

# Contributing

Contributions are welcome! Please feel free to submit a PR.


# License

MIT

