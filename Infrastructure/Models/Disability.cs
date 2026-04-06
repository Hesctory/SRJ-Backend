using System;
using System.Collections.Generic;

namespace SRJBackend.Infrastructure.Models;

public partial class Disability
{
    public int StudentId { get; set; }

    public bool HasDisabilityCertificate { get; set; }

    public int? DisabilityTypeId { get; set; }

    public int? DisabilityDegreeId { get; set; }

    public virtual DisabilityCertificateNumber? DisabilityCertificateNumber { get; set; }

    public virtual DisabilityDegree? DisabilityDegree { get; set; }

    public virtual DisabilityType? DisabilityType { get; set; }

    public virtual Student Student { get; set; } = null!;
}
