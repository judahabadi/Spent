import DeviceActivity

@main
struct SpentActivityReportExtension: DeviceActivityReportExtension {
    var body: some DeviceActivityReportScene {
        TotalActivityScene { model in
            TotalActivityView(model: model)
        }
    }
}
