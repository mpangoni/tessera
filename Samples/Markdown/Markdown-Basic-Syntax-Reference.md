# Markdown Basic Syntax Reference


A compact reference for common Markdown elements. Each section shows source syntax in a code sample, followed by a rendered example where that makes the result clearer.

This guide follows the [Markdown Guide’s Basic Syntax reference](https://www.markdownguide.org/basic-syntax/). Markdown processors differ in a few details, so check the target app when exact rendering matters.

——


## Headings

Use one to six `#` characters for heading levels one through six. Put a space after the markers.

```markdown
# Heading 1
## Heading 2
### Heading 3
#### Heading 4
##### Heading 5
###### Heading 6
```

The first two levels can also use an underline style:

```markdown
Heading 1
=========

Heading 2
---------
```

## Paragraphs and line breaks

A blank line starts a new paragraph. A single source newline is usually treated as a space within the same paragraph.

```markdown
This is the first paragraph.

This is a second paragraph.
```

To force a line break without starting a new paragraph, use two trailing spaces or an HTML `<br>` tag. The tag is easier to see in source:

```markdown
First line<br>
Second line
```

## Emphasis

Use one asterisk for *italic* text, two for **bold**, and three for ***bold italic***. Asterisks are a reliable choice when emphasis appears within a word.

```markdown
*italic*
**bold**
***bold and italic***
An un*usually* emphasized word
```

## Blockquotes

Start quoted lines with `>`. Put the marker on blank lines between quoted paragraphs as well.

```markdown
> A short quotation can span more than one line.
>
> A blank quoted line keeps the next paragraph inside the quote.
```


> A short quotation can span more than one line. 
>
> A blank quoted line keeps the next paragraph inside the quote.


Quotes can be nested by adding another marker:

```markdown
> Outer quote
>
> > Nested quote
```

> Outer quote
>
> > Nested quote


Blockquotes can also contain other Markdown, such as a heading or list:

```markdown
> ### Notes
>
> - Keep related points together.
> - Use a blank quoted line before a new paragraph.
```

> ### Notes
>
> - Keep related points together.
> - Use a blank quoted line before a new paragraph.


## Lists

### Unordered lists

Use `-`, `*`, or `+` before each item. Pick one marker and use it consistently within a list.

```markdown
- First item
- Second item
- Third item
```

Indent nested items beneath their parent:

```markdown
- Main topic
  - Supporting point
  - Another point
- Next topic
```

### Ordered lists

Use a number and a period. The source numbers may all be `1`; renderers usually number the items in order.

```markdown
1. Gather the notes
1. Sort the notes
1. Share the result
```

Ordered and unordered lists can be nested together:

```markdown
1. Prepare the draft
2. Review the details
   - Check names
   - Check dates
3. Publish the final copy
```

For compatibility, use periods rather than `)` as ordered-list markers. If a line begins with a number and period but should remain ordinary text, escape the period: `1968\. A year in a sentence.`

## Code

Use backticks for inline `code`, commands, file names, and short snippets.

```markdown
Run `swift test` before sharing the change.
```

For a code span that itself contains a backtick, surround it with a longer run of backticks:

```markdown
``Use `code` inside this phrase``
```

Use a fenced block for multiple lines. Add a language name after the opening fence to enable syntax highlighting in supporting apps.

````markdown
```swift
let greeting = "Hello, Markdown"
print(greeting)
```
````

Indented code blocks are another option. Indent each code line by four spaces:

````markdown
    let answer = 42
    print(answer)
````

## Horizontal rules

Place at least three matching hyphens, asterisks, or underscores on a line by themselves. Leave blank lines around the rule so it is not read as a heading underline.

```markdown
---

***

___
```

## Links

For an inline link, put the visible text in brackets and the destination in parentheses. An optional title appears in quotes.

```markdown
[Markdown Guide](https://www.markdownguide.org/)
[Project home](https://example.org "Optional hover title")
```

Reference-style links keep long destinations out of the paragraph:

```markdown
Read the [syntax reference][basic-markdown].

[basic-markdown]: https://www.markdownguide.org/basic-syntax/
```

Some processors automatically turn angle-bracketed URLs and email addresses into links:

```markdown
<https://example.org>
<reader@example.org>
```

## Images

Image syntax resembles a link, with an exclamation mark before the brackets. The bracket text is alternative text for people who cannot see the image and for assistive technology.

```markdown
![A green square on a white background](images/green-square.png "Optional image title")
```

The destination can be a relative file path or a URL, depending on the document and application.

## Escaping Markdown characters

Add a backslash before a Markdown punctuation character when you want it to appear literally instead of acting as formatting.

```markdown
\*These asterisks stay visible\*
\# This is not a heading
\[This is not a link\]
```

Common escapable characters include backslash, backtick, asterisk, underscore, braces, brackets, parentheses, angle brackets, hash, plus, minus, period, exclamation mark, and pipe.

## HTML

Some Markdown processors allow HTML tags inside a Markdown document. For example, `<br>` can add a line break. HTML support and filtering differ by app, so prefer ordinary Markdown when it can express the same result.

```markdown
Line one<br>
Line two
```

## Quick reference

- Heading: `## Heading`
- Italic: `*text*`
- Bold: `**text**`
- Blockquote: `> quote`
- Unordered item: `- item`
- Ordered item: `1. item`
- Inline code: `` `code` ``
- Link: `[label](https://example.org)`
- Image: `![description](image.png)`
- Horizontal rule: `---`

## Source

For more examples and compatibility notes, see the [Markdown Guide: Basic Syntax](https://www.markdownguide.org/basic-syntax/).
