// EconStack Report Template for Typst
// Professional consulting-quality PDF output

#let econstack-report(
  title: none,
  subtitle: none,
  date: none,
  prepared-by: "EconStack",
  confidential: false,
  body,
) = {

  // ----- Page setup -----
  set page(
    paper: "a4",
    margin: (top: 30mm, bottom: 25mm, left: 20mm, right: 20mm),
    header: context {
      if counter(page).get().first() > 1 {
        set text(size: 8pt, fill: rgb("#999999"))
        grid(
          columns: (1fr, 1fr),
          align(left)[*econstack*],
          align(right)[#title],
        )
        v(2pt)
        line(length: 100%, stroke: 0.4pt + rgb("#CCCCCC"))
      }
    },
    footer: context {
      if counter(page).get().first() > 1 {
        set text(size: 7pt, fill: rgb("#999999"))
        line(length: 100%, stroke: 0.3pt + rgb("#EEEEEE"))
        v(4pt)
        grid(
          columns: (1fr, auto, 1fr),
          align(left)[Data from official UK government sources],
          align(center)[econprofile.com],
          align(right)[#counter(page).display()],
        )
      }
    },
  )

  // ----- Typography -----
  set text(
    font: ("Inter", "Helvetica Neue", "Helvetica", "Arial"),
    size: 10.5pt,
    fill: rgb("#333333"),
  )

  set par(
    leading: 0.75em,
    justify: false,
  )

  // ----- Headings -----
  show heading.where(level: 1): it => {
    v(16pt)
    set text(size: 16pt, weight: "bold", fill: rgb("#003078"))
    it.body
    v(4pt)
    line(length: 100%, stroke: 1pt + rgb("#003078"))
    v(8pt)
  }

  show heading.where(level: 2): it => {
    v(12pt)
    set text(size: 13pt, weight: "bold", fill: rgb("#003078"))
    it.body
    v(4pt)
  }

  show heading.where(level: 3): it => {
    v(8pt)
    set text(size: 11pt, weight: "bold", fill: rgb("#555555"))
    it.body
    v(2pt)
  }

  // ----- Tables -----
  set table(
    stroke: none,
    inset: (x: 8pt, y: 6pt),
    fill: (_, row) => {
      if row == 0 { rgb("#003078") }
      else if calc.rem(row, 2) == 1 { rgb("#F8F9FA") }
      else { white }
    },
  )

  show table.cell.where(y: 0): set text(
    fill: white,
    weight: "bold",
    size: 9.5pt,
  )

  show table.cell: set text(size: 9.5pt)

  // Add thin horizontal rules between rows
  show table: it => {
    block(width: 100%, {
      it
      v(2pt)
    })
  }

  // ----- Links -----
  show link: set text(fill: rgb("#003078"))

  // ----- Emphasis/strong -----
  show strong: set text(fill: rgb("#003078"))

  // ----- Horizontal rule -----
  show line: it => {
    v(4pt)
    it
    v(4pt)
  }

  // ----- Block quotes (callout boxes) -----
  show quote: it => {
    block(
      width: 100%,
      inset: (left: 14pt, rest: 10pt),
      fill: rgb("#EDF6FF"),
      stroke: (left: 3pt + rgb("#003078")),
      radius: 2pt,
      it.body,
    )
  }

  // ===== COVER PAGE =====
  page(
    header: none,
    footer: none,
    margin: (top: 50mm, bottom: 40mm, left: 25mm, right: 25mm),
  )[
    // Navy accent bar at top
    place(top + left, dx: -25mm, dy: -50mm,
      rect(width: 100% + 50mm, height: 8mm, fill: rgb("#003078"))
    )

    #v(40mm)

    // Title
    #if title != none {
      text(size: 28pt, weight: "bold", fill: rgb("#003078"))[#title]
      v(8pt)
    }

    // Subtitle
    #if subtitle != none {
      text(size: 14pt, fill: rgb("#666666"))[#subtitle]
      v(16pt)
    }

    // Thin rule
    #line(length: 60%, stroke: 1pt + rgb("#003078"))

    #v(16pt)

    // Metadata
    #set text(size: 11pt, fill: rgb("#666666"))

    #if date != none {
      [*Date:* #date]
      linebreak()
    }

    [*Prepared by:* #prepared-by]
    linebreak()

    #if confidential {
      v(8pt)
      text(size: 9pt, weight: "bold", fill: rgb("#E76F51"))[CONFIDENTIAL]
    }

    // Footer on cover
    #v(1fr)
    #set text(size: 8pt, fill: rgb("#999999"))
    #line(length: 100%, stroke: 0.3pt + rgb("#CCCCCC"))
    #v(4pt)
    Data sourced from ONS, BRES, ASHE, DLUHC, and other official UK government statistics.
    #linebreak()
    Powered by econprofile.com
  ]

  // ===== BODY =====
  // Reset page counter after cover
  counter(page).update(1)

  // Section numbering
  set heading(numbering: "1.1")

  body
}

// Export the template function
#show: econstack-report.with(
  title: "Report Title",
  subtitle: "Subtitle",
  date: "2026-04-03",
)
