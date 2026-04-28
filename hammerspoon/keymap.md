# Comprehensive Key Handling Mapping

This reference defines the concrete step-by-step logic execution for every keystroke captured by the state machine.

_(Note: "Inject `[Key]`" implies creating a macOS `CGEvent` for `KeyDown` with necessary modifiers, posting it, followed immediately by its corresponding `KeyUp` event)._

## 1. Mode Transitions (Entering & Exiting)

- `Escape`:
  - **Insert**: Switch state to `Normal` -> **Suppress**.
  - **Normal**: Clear command buffer (if any counts/operators pending) -> **Suppress** (or PassThrough if buffer was empty, to allow system Esc).
  - **Visual**: Switch state to `Normal` -> Inject `Arrow Left` (to clear system string selection) -> **Suppress**.

- `i` (Insert):
  - **Insert**: **PassThrough**.
  - **Normal**: Switch to Insert -> **Suppress**.
  - **Visual**: **PassThrough** (or custom mapping).

- `I` (Insert at Start):
  - **Normal**: Inject `Cmd + Arrow Left` -> Switch to Insert -> **Suppress**.

- `a` (Append):
  - **Normal**: Inject `Arrow Right` -> Switch to Insert -> **Suppress**.

- `A` (Append at End):
  - **Normal**: Inject `Cmd + Arrow Right` -> Switch to Insert -> **Suppress**.

- `v` (Visual Mode):
  - **Insert**: **PassThrough**.
  - **Normal**: Switch to `Visual` -> **Suppress**.
  - **Visual**: Switch to `Normal` -> Inject `Arrow Left` (clear selection) -> **Suppress**.

## 2. Navigation & Motions

### Basic Movement

- `h`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Arrow Left` (Repeat `n` times if count buffer > 0) -> **Suppress**.
  - **Visual**: Inject `Shift + Arrow Left` -> **Suppress**.
  - **Operator Pending (e.g. `d`, `c`)**: Inject `Shift + Arrow Left` -> Execute Operator Action (e.g., Cut) -> Switch to Normal/Insert -> **Suppress**.

- `j`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Arrow Down` -> **Suppress**.
  - **Visual**: Inject `Shift + Arrow Down` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Arrow Down` -> Execute Operator -> **Suppress** (if `dj`, select down then cut).

- `k`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Arrow Up` -> **Suppress**.
  - **Visual**: Inject `Shift + Arrow Up` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Arrow Up` -> Execute Operator -> **Suppress**.

- `l`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Arrow Right` -> **Suppress**.
  - **Visual**: Inject `Shift + Arrow Right` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Arrow Right` -> Execute Operator -> **Suppress**.

### Word Movement

- `w` / `e`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Option + Arrow Right` -> **Suppress**.
  - **Visual**: Inject `Shift + Option + Arrow Right` -> **Suppress**.
  - **Operator Pending (`dw`, `cw`)**: Inject `Shift + Option + Arrow Right` -> Execute Operator -> **Suppress**.

- `b`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Option + Arrow Left` -> **Suppress**.
  - **Visual**: Inject `Shift + Option + Arrow Left` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Option + Arrow Left` -> Execute Operator -> **Suppress**.

### Line Boundaries

- `0`:
  - **Insert**: **PassThrough**.
  - **Normal**: (If count buffer empty) Inject `Command + Arrow Left` -> **Suppress**. (If count > 0, treat as digit `0` -> buffer).
  - **Visual**: Inject `Shift + Command + Arrow Left` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Command + Arrow Left` -> Execute Operator -> **Suppress**.

- `$`:
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Command + Arrow Right` -> **Suppress**.
  - **Visual**: Inject `Shift + Command + Arrow Right` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Command + Arrow Right` -> Execute Operator -> **Suppress**.

### File & Page Boundaries

- `gg`:
  - **Normal**: Buffer `g` on first press. On second press: Inject `Command + Arrow Up` -> Clear buffer -> **Suppress**.
  - **Visual**: Inject `Shift + Command + Arrow Up` -> **Suppress**.
  - **Operator Pending (`dgg`)**: Inject `Shift + Command + Arrow Up` -> Execute Operator -> **Suppress**.

- `G`:
  - **Normal**: Inject `Command + Arrow Down` -> **Suppress**.
  - **Visual**: Inject `Shift + Command + Arrow Down` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + Command + Arrow Down` -> Execute Operator -> **Suppress**.

- `Ctrl + d` (Page Down):
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `PageDown` (or `Fn + Arrow Down`) -> **Suppress**.
  - **Visual**: Inject `Shift + PageDown` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + PageDown` -> Execute Operator -> **Suppress**.

- `Ctrl + u` (Page Up):
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `PageUp` (or `Fn + Arrow Up`) -> **Suppress**.
  - **Visual**: Inject `Shift + PageUp` -> **Suppress**.
  - **Operator Pending**: Inject `Shift + PageUp` -> Execute Operator -> **Suppress**.

## 3. Operators (Actions awaiting a motion)

- `d` (Delete):
  - **Insert**: **PassThrough**.
  - **Normal**:
    - If empty buffer: Buffer `d` -> **Suppress**.
    - If buffer has `d` (i.e., `dd`): Inject `Cmd+Left` -> `Shift+Cmd+Right` -> `Cmd+X` -> `Delete` -> Clear buffer -> **Suppress**.
  - **Visual**: Inject `Cmd+X` -> Switch to Normal -> **Suppress**.

- `c` (Change):
  - **Insert**: **PassThrough**.
  - **Normal**:
    - If empty buffer: Buffer `c` -> **Suppress**.
    - If buffer has `c` (i.e., `cc`): Inject `Cmd+Left` -> `Shift+Cmd+Right` -> `Cmd+X` -> Switch to Insert -> **Suppress**.
  - **Visual**: Inject `Cmd+X` -> Switch to Insert -> **Suppress**.
  - _(Note on pending `c` + motion)_: Performs motion with selection -> Injects `Cmd+X` -> Switches to Insert.

- `y` (Yank):
  - **Insert**: **PassThrough**.
  - **Normal**:
    - If empty buffer: Buffer `y` -> **Suppress**.
    - If buffer has `y` (i.e., `yy`): Inject `Cmd+Left` -> `Shift+Cmd+Right` -> `Cmd+C` -> `Arrow Left` (clear selection) -> Clear buffer -> **Suppress**.
  - **Visual**: Inject `Cmd+C` -> Inject `Arrow Left` -> Switch to Normal -> **Suppress**.

## 4. Instant Edits & Actions

- `x` (Delete char):
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `ForwardDelete` (or `Cmd+X` to save to clipboard if cloning yank behavior exactly) -> **Suppress**.
  - **Visual**: Inject `Cmd+X` -> Switch to Normal -> **Suppress**.

- `p` (Paste):
  - **Insert**: **PassThrough**.
  - **Normal**: If pasting line -> Inject `Cmd+Right` (end of line) -> Inject `Enter` -> Inject `Cmd+V`. If pasting inline -> Inject `Arrow Right` -> Inject `Cmd+V` -> **Suppress**.
  - **Visual**: Inject `Cmd+V` (replaces selection) -> Switch to Normal -> **Suppress**.

- `u` (Undo):
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Cmd + Z` -> **Suppress**.
  - **Visual**: Switch to Normal -> Inject `Cmd + Z` -> **Suppress**.

- `Ctrl + r` (Redo):
  - **Insert**: **PassThrough**.
  - **Normal**: Inject `Cmd + Shift + Z` -> **Suppress**.
  - **Visual**: Switch to Normal -> Inject `Cmd + Shift + Z` -> **Suppress**.

## 5. Modifiers & Counters

- `1-9`:
  - **Insert**: **PassThrough**.
  - **Normal/Visual**: Parse string as integer -> Append to Command buffer's count -> **Suppress**.
