import type { ShikiTransformer, ThemeRegistrationRaw } from "shiki";

/**
 * Solidity highlighting for the cut sheets.
 *
 * The scope list below is not guessed — it is every scope the Shiki Solidity
 * grammar actually emits across all 20 hook excerpts, grouped by what the token
 * means to a hook author rather than by generic "keyword / string / number":
 *
 *   permission  pink    visibility, mutability, modifiers, msg.sender — who may call
 *   type        cyan    uint256/address plus the v4 structs (PoolKey, BeforeSwapDelta)
 *   keyword     violet  control flow and declarations
 *   literal     amber   numbers and strings
 *   error       red     revert / require / custom error names
 *
 * Colours are CSS variables so both site themes keep working from one theme object.
 */
const fg = "var(--c-fg)";

export const solidityTheme: ThemeRegistrationRaw = {
  name: "v4hooks",
  type: "dark",
  fg,
  bg: "transparent",
  settings: [
    { scope: ["comment.line", "comment.block", "comment"], settings: { foreground: "var(--c-comment)", fontStyle: "italic" } },

    // Access control: the thing this whole site is about.
    {
      scope: [
        "storage.type.modifier.access", // public, internal, external
        "storage.type.modifier.extendedscope", // pure, view, virtual, override, memory, calldata
        "storage.type.modifier.readonly", // immutable
        "entity.name.function.modifier", // onlyPoolManager, nonReentrant
        "variable.language.transaction", // msg.sender, block
        "variable.language.this",
      ],
      settings: { foreground: "var(--c-perm)" },
    },

    // Types — primitives and the v4 structs read as one family.
    {
      scope: [
        "support.type.primitive",
        "storage.type.struct",
        "entity.name.type.contract",
        "entity.name.type.contract.extend",
        "support.variable.property",
      ],
      settings: { foreground: "var(--c-type)" },
    },

    // Failure paths stay rare, so red stays meaningful.
    { scope: ["keyword.control.exceptions", "entity.name.type.error"], settings: { foreground: "var(--c-err)" } },

    {
      scope: [
        "keyword.control.flow",
        "keyword.control.flow.return",
        "storage.type.function",
        "storage.type.contract",
        "storage.type.error",
        "storage.type.constructor",
        "storage.type.function.modifier",
        "storage.modifier.is",
      ],
      settings: { foreground: "var(--c-key)" },
    },

    { scope: ["entity.name.function"], settings: { foreground: "var(--c-fn)" } },
    { scope: ["variable.parameter.other", "variable.parameter.function"], settings: { foreground: "var(--c-var)" } },
    {
      scope: ["constant.numeric.decimal", "constant.numeric", "string.quoted.double", "string", "constant.other.underscore"],
      settings: { foreground: "var(--c-lit)" },
    },

    // Base colour; the transformer below splits true from false.
    { scope: ["constant.language.boolean"], settings: { foreground: "var(--c-lit)" } },

    { scope: ["keyword.operator.logic", "keyword.operator.assignment", "keyword.operator.arithmetic", "keyword.operator.binary"], settings: { foreground: "var(--c-op)" } },
    {
      scope: [
        "punctuation.separator",
        "punctuation.terminator.statement",
        "punctuation.accessor",
        "punctuation.parameters.begin",
        "punctuation.parameters.end",
        "punctuation.brace.curly.begin",
        "punctuation.brace.curly.end",
        "punctuation.brace.square.begin",
        "punctuation.brace.square.end",
      ],
      settings: { foreground: "var(--c-punc)" },
    },
  ],
};

/**
 * `getHookPermissions` is the densest thing on a cut sheet — 243 booleans across
 * the corpus, more than any token except punctuation. Colouring `true` bright and
 * `false` dim makes a permissions block scannable the same way the bit strip is:
 * lit means that callback runs.
 *
 * Writing `style` directly rather than adding a class avoids fighting Shiki's own
 * inline style for specificity.
 */
export const booleanEmphasis: ShikiTransformer = {
  name: "v4hooks:solidity-booleans",
  span(node) {
    const child = node.children?.[0];
    if (!child || child.type !== "text") return;
    // Shiki folds the leading indentation into the token, so this is " true", not "true".
    const word = child.value.trim();
    if (word === "true" || word === "false") {
      node.properties = { ...node.properties, style: `color:var(--c-${word})` };
    }
  },
};
