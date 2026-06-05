using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Familiar
{
    public int PersonId { get; set; }

    public int? LevelOfEducationId { get; set; }

    public string? Occupation { get; set; }

    public string? Workplace { get; set; }

    public bool Lives { get; set; }

    public virtual ICollection<FamiliarStudentRelationship> FamiliarStudentRelationships { get; set; } = new List<FamiliarStudentRelationship>();

    public virtual LevelOfEducation? LevelOfEducation { get; set; }

    public virtual Person Person { get; set; } = null!;
}
