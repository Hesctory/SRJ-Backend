using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SchoolFee
{
    public int Id { get; set; }

    public int SchoolYearId { get; set; }

    public int LevelId { get; set; }

    public int ShiftId { get; set; }

    public int SchoolFeeConceptId { get; set; }

    public decimal EnrollmentPrice { get; set; }

    public decimal TuitionCost { get; set; }

    public decimal RegistrationFee { get; set; }

    public string? Description { get; set; }

    public virtual Level Level { get; set; } = null!;

    public virtual SchoolFeeConcept SchoolFeeConcept { get; set; } = null!;

    public virtual SchoolYear SchoolYear { get; set; } = null!;

    public virtual Shift Shift { get; set; } = null!;
}
