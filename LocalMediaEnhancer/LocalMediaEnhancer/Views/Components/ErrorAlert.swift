//
//  ErrorAlert.swift
//  LocalMediaEnhancer
//
//  液态玻璃风格错误提示组件
//  参考: iOS 26 Human Interface Guidelines - Alerts
//

import SwiftUI

/// 可复用的错误提示 ViewModifier
struct ErrorAlertModifier: ViewModifier {
    @Binding var error: LocalizedError?
    var onDismiss: (() -> Void)?

    func body(content: Content) -> some View {
        content
            .alert(item: Binding(
                get: { error.map { ErrorWrapper(error: $0) } },
                set: { newValue in
                    if newValue == nil {
                        error = nil
                        onDismiss?()
                    }
                }
            )) { wrapper in
                Alert(
                    title: Text("出错了"),
                    message: Text(wrapper.error.errorDescription ?? "发生未知错误"),
                    primaryButton: .default(Text("确定")) {
                        error = nil
                        onDismiss?()
                    },
                    secondaryButton: .cancel()
                )
            }
    }
}

extension View {
    /// 液态玻璃风格错误弹窗
    func errorAlert(_ error: Binding<LocalizedError?>, onDismiss: (() -> Void)? = nil) -> some View {
        modifier(ErrorAlertModifier(error: error, onDismiss: onDismiss))
    }
}

/// 内联错误提示条（非弹窗形式）
struct ErrorBanner: View {
    let error: LocalizedError
    var onDismiss: (() -> Void)?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.errorDescription ?? "错误")
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let suggestion = error.recoverySuggestion {
                    Text(suggestion)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Button {
                onDismiss?()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background {
            if #available(iOS 26.0, *) {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
                    .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            } else {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(.ultraThinMaterial)
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(.orange.opacity(0.3), lineWidth: 0.5)
        }
    }
}
