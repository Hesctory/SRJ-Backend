using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class FamiliarStudentRelationship
{
    public int Id { get; set; }

    public int FamiliarId { get; set; }

    public int StudentId { get; set; }

    public bool LivesTogether { get; set; }

    public int FamiliarRelationshipTypeId { get; set; }

    public bool Isguardian { get; set; }

    public virtual Familiar Familiar { get; set; } = null!;

    public virtual FamiliarRelationshipType FamiliarRelationshipType { get; set; } = null!;

    public virtual Student Student { get; set; } = null!;
}
