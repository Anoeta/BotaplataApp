import SwiftUI

struct AuthenticationRestoringView: View { var body: some View { ZStack { BotaplataColors.background.ignoresSafeArea(); BotaplataCard { VStack(alignment: .leading, spacing: BotaplataSpacing.md) { Text("Botaplata").font(.largeTitle.bold()); Text("Restauration sécurisée de la session.").foregroundStyle(BotaplataColors.textSecondary); ProgressView().controlSize(.small) } }.padding() } } }
