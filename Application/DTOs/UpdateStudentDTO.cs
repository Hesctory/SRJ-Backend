namespace SRJBackend.Application.DTOs;

public class UpdateStudentDTO : EducationalPersonDataDTO
{
    public LocationDTO BirthLocation { get; set; } = null!;
    public bool HasElectronicDevices { get; set; }
    public bool HasInternetAccess { get; set; }
    public bool HasDisability { get; set; }
    public short? Siblings { get; set; }
    public int? ChildbirthTypeId { get; set; }
    public List<CreateFamiliarDTO> Familiars { get; set; } = new();
}
