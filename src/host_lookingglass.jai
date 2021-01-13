LKG_discover_device :: (app_name: string, verbose := false) -> (bool, []Looking_Glass_Device) {
    defer hpc.TeardownMessagePipe();

    res := hpc.InitializeApp(tprint("%\0", app_name).data, .NONCOMMERCIAL);
    if res != .NOERROR return false, .[];

    if verbose print("InitializeApp: %\n", res);

    num_displays := hpc.GetNumDevices();
    if verbose print("% device% connected.\n", num_displays, (ifx num_displays == 1 then "" else "s"));

    if num_displays == 0
        return false, .[];

    display_infos: [..]Looking_Glass_Device;
    for i: 0..num_displays - 1 {
        using info := array_add(*display_infos);

        xpos   = hpc.GetDevicePropertyWinX(i);
        ypos   = hpc.GetDevicePropertyWinY(i);
        width  = hpc.GetDevicePropertyScreenW(i);
        height = hpc.GetDevicePropertyScreenH(i);

        pitch  = hpc.GetDevicePropertyPitch(i);
        tilt   = hpc.GetDevicePropertyTilt(i);
        center = hpc.GetDevicePropertyCenter(i);
        subp   = hpc.GetDevicePropertySubp(i);
        fringe = hpc.GetDevicePropertyFringe(i);

        ri     = hpc.GetDevicePropertyRi(i);
        bi     = hpc.GetDevicePropertyBi(i);

        view_cone = hpc.GetDevicePropertyFloat(i, "/calibration/viewCone/value");
    }

    return true, display_infos;
}

#scope_file
hpc :: #import "HoloPlayCore";
#import "Basic";
