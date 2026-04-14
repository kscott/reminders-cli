// Usage.swift

import Foundation
import GetClearKit

func usage() -> Never {
    print("""
    reminders \(versionString) — CLI for Apple Reminders

    Usage:
      reminders open                                   # Open the Reminders app
      reminders lists                                  # Show all reminder lists
      reminders list [name] [by due|priority|title|created]
      reminders add <name> [list] [date]               # Add a reminder
      reminders change <name> [list] [field value]     # Change fields; use "none" to clear
      reminders rename <name> <new-name> [list]        # Rename a reminder
      reminders find <query>                           # Search titles and notes
      reminders show <name> [list]                     # Show full detail of a reminder
      reminders done <name> [list]                     # Mark a reminder done
      reminders remove <name> [list]                   # Remove a reminder

    Date examples:
      tomorrow, friday, "next friday", "march 15", "2026-03-10", 3pm, "friday at 5pm"

    Optional fields (any order, note must be last):
      repeat daily / repeat weekly / repeat "last tuesday" / repeat "every 2 weeks"
      priority high / priority medium / priority low / priority none
      url https://example.com
      note your free text goes here to end of line

    Clear a field with change:
      due none / repeat none / note none / url none / priority none

    Feedback: https://github.com/kscott/get-clear/issues
    """)
    exit(0)
}
