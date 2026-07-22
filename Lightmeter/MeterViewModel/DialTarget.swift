/// The single control currently driven by the shared ruler dial.
enum DialTarget: Equatable {
    case component(ExposureComponent)
    case compensation
}
