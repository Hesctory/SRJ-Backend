using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class SchoolYear
{
    public int Id { get; set; }

    public short Year { get; set; }

    public DateOnly StartDate { get; set; }

    public DateOnly? EndDate { get; set; }

    public bool? IsActive { get; set; }

    public virtual ICollection<GradeOffering> GradeOfferings { get; set; } = new List<GradeOffering>();

    public virtual ICollection<SchoolFee> SchoolFees { get; set; } = new List<SchoolFee>();
}
