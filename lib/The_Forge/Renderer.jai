DIRECT3D12 :: true;
VULKAN     :: false;
METAL      :: false;
DIRECT3D11 :: false;
ORBIS      :: false;
PROSPERO   :: false;

Queue :: struct
{
#if DIRECT3D12 {
    dxQueue: *ID3D12CommandQueue;
    union {
	//uint32_t             mType : 3;
	//uint32_t             mNodeIndex : 4;
        type: u32;
        nodeIndex: u32;
    }
    fence: *Fence;
}

#if VULKAN {
	pVkQueue: VkQueue;
	pSubmitMutex: *Mutex;
    union {
        //uint32_t             mVkQueueFamilyIndex : 5;
        //uint32_t             mVkQueueIndex : 5;
        //uint32_t             mType : 3;
        //uint32_t             mNodeIndex : 4;
        //uint32_t             mGpuMode : 3;
        vkQueueFamilyIndex: u32;
        vkQueueIndex: u32;
        type: u32;
        nodeIndex: u32;
        gpuMode: u32;
    }
    flags: u32;
    timestampPeriod: float;
}

#if METAL {
	//id<MTLCommandQueue>  mtlCommandQueue;
	//id<MTLFence>         mtlQueueFence API_AVAILABLE(macos(10.13), ios(10.0));
	//uint32_t             mBarrierFlags;
	//uint32_t             mType : 3;
	//uint32_t             mNodeIndex : 4;
	//uint32_t             mPadB;
    mtlCommandQueue: *void;
    mtlQueueFence: *void;
    barrierFlags: u32;
    union {
        type: u32;
        nodeIndex: u32;
    }
    padB: u32;
}

#if DIRECT3D11 {
    dxDevice: *ID3D11Device;
    dxContext: *ID3D11DeviceContext;
    union {
        //uint32_t             mType : 3;
        //uint32_t             mNodeIndex : 4;
        type: u32;
        nodeIndex: u32;
    }
    fence: *Fence;
}

#if ORBIS {
    mStruct: OrbisQueue;
    union {
        type: u32;
        nodeIndex: u32;
    }

}
#if PROSPERO {
    mStruct: ProsperoQueue;
    union {
        //uint32_t             mType : 3;
        //uint32_t             mNodeIndex : 4;
        type: u32;
        nodeIndex: u32;
    }
}
}
