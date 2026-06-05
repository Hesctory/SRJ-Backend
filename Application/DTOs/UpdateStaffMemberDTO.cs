namespace SRJBackend.Application.DTOs;

public class UpdateStaffMemberDTO : PersonDataDTO
{
    public int? LevelOfEducationId { get; set; }
    public string? ProfessionalTitle { get; set; }
    public string? EmployeeCode { get; set; }
    public string? PreviousInstitution { get; set; }
    public string? SpouseName { get; set; }
    public string? SpouseDocumentNumber { get; set; }
    public string? SpouseOccupation { get; set; }
    public short? NumberOfChildren { get; set; }
    public string? Comment { get; set; }
}
