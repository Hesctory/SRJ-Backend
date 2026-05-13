namespace SRJBackend.Domain.ValueObjects;

public record StudentProfile(
    bool HasElectronicDevices,
    bool HasInternetAccess,
    bool HasDisability,
    short? Siblings,
    int? ChildbirthTypeId
);
