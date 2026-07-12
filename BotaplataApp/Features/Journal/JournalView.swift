import SwiftUI
struct JournalView: View { let events: [String]; var body: some View { List(events, id: \.self) { Text($0).padding(.vertical, 6) }.navigationTitle("Journal").scrollContentBackground(.hidden).background(BotaplataColors.background) } }
#Preview { NavigationStack { JournalView(events: PreviewFixtures.journalEvents) } }
