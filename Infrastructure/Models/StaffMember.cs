using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class StaffMember
{
    public int PersonId { get; set; }

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

    public virtual ICollection<EmploymentContract> EmploymentContracts { get; set; } = new List<EmploymentContract>();

    public virtual LevelOfEducation? LevelOfEducation { get; set; }

    public virtual Person Person { get; set; } = null!;
}
