import SwiftUI

struct ButtonView: View {
    
    @ObservedObject var activeVideo: ActiveVideo
    @State var activeNumber: Int?
    
    var body: some View {
        if #available(iOS 17.0, *) {
            HStack {
                ButtonGroupView(activeNumber: $activeNumber)
            }
            .sensoryFeedback(.impact, trigger: activeNumber)
            .padding()
            .onAppear(perform: {
                switch activeVideo.activeVideo {
                case "front":
                    activeNumber = 1
                case "back":
                    activeNumber = 2
                case "left":
                    activeNumber = 3
                case "rigth":
                    activeNumber = 4
                case .none:
                    break
                case .some(_):
                    break
                }
            })
        } else {
            HStack {
                ButtonGroupView(activeNumber: $activeNumber)
            }
            .padding()
            .onAppear(perform: {
                switch activeVideo.activeVideo {
                case "front":
                    activeNumber = 1
                case "back":
                    activeNumber = 2
                case "left":
                    activeNumber = 3
                case "rigth":
                    activeNumber = 4
                case .none:
                    break
                case .some(_):
                    break
                }
            })
        }
    }
}

struct ButtonGroupView: View {
    @Binding var activeNumber: Int?
    
    var body: some View {
        HStack {
            Button("전") {
                activeNumber = 1
            }
            .buttonStyle(FullWidthButtonStyle())
            .scaleEffect(activeNumber == 1 ? 1.2 : 1.0)
            .fontWeight(activeNumber == 1 ? .bold : .regular)
            .animation(.easeInOut(duration: 0.2), value: activeNumber)
            
            Button("후") {
                activeNumber = 2
            }
            .buttonStyle(FullWidthButtonStyle())
            .scaleEffect(activeNumber == 2 ? 1.2 : 1.0)
            .fontWeight(activeNumber == 2 ? .bold : .regular)
            .animation(.easeInOut(duration: 0.2), value: activeNumber)
            
            Button("좌") {
                activeNumber = 3
            }
            .buttonStyle(FullWidthButtonStyle())
            .scaleEffect(activeNumber == 3 ? 1.2 : 1.0)
            .fontWeight(activeNumber == 3 ? .bold : .regular)
            .animation(.easeInOut(duration: 0.2), value: activeNumber)
            
            Button("우") {
                activeNumber = 4
            }
            .buttonStyle(FullWidthButtonStyle())
            .scaleEffect(activeNumber == 4 ? 1.2 : 1.0)
            .fontWeight(activeNumber == 4 ? .bold : .regular)
            .animation(.easeInOut(duration: 0.2), value: activeNumber)
        }
    }
}

struct FullWidthButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.title3)
            .frame(maxWidth: .infinity, minHeight: 50) // 모든 버튼에 동일한 최대 너비 적용
            .contentShape(Rectangle()) // 탭 가능 영역을 레이블 전체로 확장
            .background(Color.white)
            .foregroundStyle(Color.blue)
            .clipShape(RoundedRectangle(cornerSize: CGSize(width: 10, height: 10)))
            .padding(1)
    }
}

#Preview {
    ButtonView(activeVideo: ActiveVideo())
        .environment(\.colorScheme, .dark)
}
