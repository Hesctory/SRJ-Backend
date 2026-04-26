using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class FamiliarRelationshipType
{
    public int Id { get; set; }

    public string Name { get; set; } = null!;

    public virtual ICollection<FamiliarStudentRelationship> FamiliarStudentRelationships { get; set; } = new List<FamiliarStudentRelationship>();
}
