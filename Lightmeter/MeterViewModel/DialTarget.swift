/// The single control currently driven by the shared arc dial.
enum DialTarget: Equatable {
    case component(ExposureComponent)
    case compensation
}
