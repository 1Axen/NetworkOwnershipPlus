return {
    NetworkRecipient = {
        Server = 1,
        Player = 2,
        AllPlayers = 3,
    },

    ReplicationState = {
        Always = 1,
        DontSend = 2,
        OnlyVisible = 3,
        Manual = 4, --> Calls the entities ShouldReplicate function
    },

    SystemEvent = {
        Initialize = 0,
        CreateEntity = 1,
        DestroyEntity = 2,
        WorldSnapshot = 3,
        AssignOwnership = 4,
        RemoveOwnership = 5,
        ProcessEntityEvent = 6,
        RequestFullSnapshot = 7,
    },

    EntityEvent = {
        Command = 1,
        Custom = 2,
    },

    ConnectionType = {
        Reliable = 1,
        Unreliable = 2
    }
}