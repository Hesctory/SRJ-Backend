namespace SRJBackend.Application.DTOs;

public class LocationDTO
{
    public int DepartmentId { get; set; }
    public int ProvinceId { get; set; }
    public int DistrictId { get; set; }
}

public class PersonDataDTO
{
    public string Names { get; set; } = null!;
    public string PaternalLastname { get; set; } = null!;
    public string MaternalLastname { get; set; } = null!;
    public int GenderId { get; set; }
    public DateOnly BirthDate { get; set; }
    public int DocumentTypeId { get; set; }
    public string IdDocumentNumber { get; set; } = null!;
    public int? ReligionId { get; set; }
    public int? CivilStateId { get; set; }
    public string? Address { get; set; }
    public LocationDTO? AddressLocation { get; set; }
    public string? Email { get; set; }
    public string? LandlinePhone { get; set; }
    public string? CellPhone { get; set; }
}

public class EducationalPersonDataDTO : PersonDataDTO
{
    public int NativeLanguageId { get; set; }
    public int? EthnicSelfIdentificationId { get; set; }
    public List<int>? SecondLanguageIds { get; set; }
}

public class CreateFamiliarDTO : EducationalPersonDataDTO
{
    public int? LevelOfEducationId { get; set; }
    public string? Occupation { get; set; }
    public string? WorkCenter { get; set; }
    public bool Lives { get; set; }
    public bool LivesWithStudent { get; set; }
    public int RelationshipId { get; set; }
    public bool IsGuardian { get; set; }
}

public class CreateStudentDTO : EducationalPersonDataDTO
{
    public LocationDTO BirthLocation { get; set; } = null!;
    public bool HasElectronicDevices { get; set; }
    public bool HasInternetAccess { get; set; }
    public bool HasDisability { get; set; }
    public short? Siblings { get; set; }
    public int? ChildbirthTypeId { get; set; }
    public List<CreateFamiliarDTO> Familiars { get; set; } = new();
    public CreateEnrollmentDTO Enrollment { get; set; } = null!;
}
