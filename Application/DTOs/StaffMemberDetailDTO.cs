namespace SRJBackend.Application.DTOs;

public class StaffMemberDetailDTO
{
    public int Id { get; set; }
    public string Names { get; set; } = null!;
    public string PaternalLastname { get; set; } = null!;
    public string MaternalLastname { get; set; } = null!;
    public string FullName { get; set; } = null!;
    public int GenderId { get; set; }
    public DateOnly BirthDate { get; set; }
    public int DocumentTypeId { get; set; }
    public string IdDocumentNumber { get; set; } = null!;
    public int? ReligionId { get; set; }
    public int? CivilStateId { get; set; }
    public string? Address { get; set; }
    public int AddressUbigeoId { get; set; }
    public LocationDTO? AddressLocation { get; set; }
    public string? Email { get; set; }
    public string? LandlinePhone { get; set; }
    public string? CellPhone { get; set; }
    public int? LevelOfEducationId { get; set; }
    public string? ProfessionalTitle { get; set; }
    public string? EmployeeCode { get; set; }
    public string? PreviousInstitution { get; set; }
    public string? SpouseName { get; set; }
    public string? SpouseDocumentNumber { get; set; }
    public string? SpouseOccupation { get; set; }
    public short? NumberOfChildren { get; set; }
    public string? Comment { get; set; }
    public bool IsActive { get; set; }
    public bool IsArchived { get; set; }
    public List<EmploymentContractDTO> Contracts { get; set; } = new();
}
